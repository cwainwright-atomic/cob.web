//
//  CobOrder+Controller.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Vapor
import Fluent
import Crumbs

extension CobOrder {
    struct Controller : RouteCollection {
        func boot(routes: any Vapor.RoutesBuilder) throws {
            let orders = routes.grouped("orders")
            
            //MARK: Public Endpoint
            orders.get(use: Week.get)
            
            //MARK: Authenticated Endpoints
            let personal = orders
                .grouped("me")
                .grouped(UserToken.authenticator())
            
            personal.get(use: Personal.get)
            personal.post(use: Personal.post)
            personal.delete(use: Personal.delete)
            
            personal.get("history", use: Personal.history)
            
            //MARK: Recurring Orders Endpoints
            let recurring = personal.grouped("recurring")
            recurring.get(use: Personal.Recurring.get)
            recurring.post(use: Personal.Recurring.post)
            recurring.delete(use: Personal.Recurring.delete)
            recurring.post("reset", use: Personal.Recurring.reset)
        }
        
        struct Week {
            static func get(_ req: Request) async throws -> WeekOrderDTO {
                let fallbackDateComponents = WeekOrder.dateComponents(Date())
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                guard let weekOrderId = try await WeekOrder.findOrCreate(on: req.db, week: week, year: year)?.requireID()
                else { throw Abort(.noContent, reason: "No order found for provided week (\(year) - \(week))") }
                
                let recurringCobOrders: [RecurringOrder] = try await RecurringOrder.query(on: req.db)
                    .join(parent: \RecurringOrder.$user).all()
                
                let exceptionCobOrders: [RecurringOrderException] = try await RecurringOrderException.query(on: req.db)
                    .join(parent: \RecurringOrderException.$user).filter(\.$weekOrder.$id == weekOrderId).all()
                
                let weekCobOrders: [CobOrder] = try await CobOrder.query(on: req.db)
                    .join(parent: \CobOrder.$user).filter(\.$weekOrder.$id == weekOrderId)
                    .all()
                
                var orders: [UUID : CobOrderDTO] = [:]
                
                try recurringCobOrders.forEach {
                    let user = try $0.joined(User.self)
                    let userDTO = UserDTO(fromUser: user)
                    let cobOrderDTO = try CobOrderDTO(fromRecurring: $0, user: userDTO)
                    orders[try user.requireID()] = cobOrderDTO
                }
                
                try exceptionCobOrders.forEach {
                    try orders.removeValue(forKey: $0.user.requireID())
                }
                
                try weekCobOrders.forEach {
                    let user = try $0.joined(User.self)
                    let userDTO = UserDTO(fromUser: user)
                    let cobOrderDTO = try CobOrderDTO(fromOrder: $0, user: userDTO)
                    orders[try user.requireID()] = cobOrderDTO
                }
                
                return WeekOrderDTO(week: week, year: year, orders: Array(orders.values))
            }
        }
        
        struct Personal {
            static func get(_ req: Request) async throws -> CobOrderDTO {
                let fallbackDateComponents = WeekOrder.dateComponents(Date())
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                let user = try req.auth.require(User.self)
                
                let (weekOrder, cobVariant) = try await req.db.transaction { transaction in
                    guard let weekOrder = try await WeekOrder.findOrCreate(on: transaction, week: week, year: year)
                    else { throw Abort(.notFound, reason: "Week order (\(year) - \(week)) could not be fetched") }
                    
                    guard let cobVariant = try await weekOrder.orderPlaced(by: user, on: transaction)
                    else { throw Abort(.notFound, reason: "No order found for user \(user.name) for week \(weekOrder.description)") }
                    
                    return (weekOrder, cobVariant)
                }
                    
                let weekOrderDTO = WeekOrderDTO(fromWeekOrder: weekOrder)

                switch cobVariant {
                case .single(let cob):
                    return try CobOrderDTO(fromOrder: cob, weekOrder: weekOrderDTO)
                case .recurring(let recurringOrder):
                    return try CobOrderDTO(fromRecurring: recurringOrder, weekOrder: weekOrderDTO)
                }
            }
            
            static func post(_ req: Request) async throws -> HTTPStatus {
                let user = try req.auth.require(User.self)
                let userId = try user.requireID()
                
                let orderDetail = try req.content.decode(CobOrderDetail.self)
                
                return try await req.db.transaction { transaction in
                    guard let weekOrderId = try await WeekOrder
                        .findOrCreate(on: transaction)?
                        .requireID()
                    else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
                    
                    if let existingCobOrder = try await CobOrder.query(on: transaction)
                        .filter(\.$user.$id == userId)
                        .filter(\.$weekOrder.$id == weekOrderId)
                        .first()
                    {
                        existingCobOrder.orderDetail = orderDetail
                        try await existingCobOrder.update(on: transaction)
                        return .ok
                    }
                    else {
                        let cobOrder = CobOrder(userId: userId, orderDetail: orderDetail, weekOrderId: weekOrderId)
                        try await cobOrder.save(on: transaction)
                        return .created
                    }
                }
            }
            
            static func delete(_ req: Request) async throws -> HTTPStatus {
                let fallbackDateComponents = WeekOrder.dateComponents(Date())
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                let user = try req.auth.require(User.self)
                
                return try await req.db.transaction { transaction in
                    guard let weekOrder = try await WeekOrder.findOrCreate(on: transaction, week: week, year: year)
                    else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
                    
                    guard let cobOrder = try await weekOrder.orderPlaced(by: user, on: transaction)
                    else { throw Abort(.notFound, reason: "No order found for user \(user.name)") }
                    
                    switch cobOrder {
                    case .single(let cobOrder):
                        req.logger.info("Single order (id: \(String(describing: try? cobOrder.requireID().uuidString))) deleted")
                        try await cobOrder.delete(on: transaction)
                    case .recurring(let recurringOrder):
                        req.logger.info("Recurring order (id: \(String(describing: try? recurringOrder.requireID().uuidString))) exception added")
                        try await RecurringOrderException(user: user, weekOrder: weekOrder).create(on: transaction)
                    }
    
                    return .ok
                }
            }
            
            static func history(_ req: Request) async throws -> [CobOrderDTO] {
                let user = try req.auth.require(User.self)
                let userId = try user.requireID()
                
                let pageIndex: Int = req.query["page"] ?? 0
                
                let orders = try await CobOrder.query(on: req.db)
                    .filter(\.$user.$id == userId)
                    .join(WeekOrder.self, on: \WeekOrder.$id == \CobOrder.$weekOrder.$id)
                    .sort( \.$createdAt, .descending)
                    .page(withIndex: pageIndex, size: 10)
                    .items
                
                var orderDTOs: [CobOrderDTO] = []
                try orders.forEach { order in
                    let weekOrderDTO = WeekOrderDTO(fromWeekOrder: try order.joined(WeekOrder.self))
                    orderDTOs.append(try CobOrderDTO(fromOrder: order, weekOrder: weekOrderDTO))
                }
                
                return orderDTOs
            }
            
            struct Recurring {
                static func get(_ req: Request) async throws -> RecurringOrderDTO {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    guard let recurringOrder = try await RecurringOrder.query(on: req.db)
                        .filter(\.$user.$id == userId)
                        .first()
                    else { throw Abort(.notFound, reason: "No recurring order found for user \(user.name)") }
                    
                    return try await RecurringOrderDTO(fromRecurringOrder: recurringOrder)
                }
                
                static func post(_ req: Request) async throws -> HTTPStatus {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()

                    let orderDetail = try req.content.decode(CobOrderDetail.self)
                    
                    return try await req.db.transaction { transaction in
                        if let existingRecurringOrder = try await RecurringOrder.query(on: transaction)
                            .filter(\.$user.$id == userId)
                            .first()
                        {
                                existingRecurringOrder.orderDetail = orderDetail
                                try await existingRecurringOrder.update(on: transaction)
                                return .ok
                        } else {
                            let newRecurringOrder = RecurringOrder(userId: userId, orderDetail: orderDetail)
                            try await newRecurringOrder.save(on: transaction)
                            return .created
                        }
                    }
                }
                
                static func delete(_ req: Request) async throws -> HTTPStatus {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    try await req.db.transaction { transaction in
                        if let existingRecurringOrder = try await RecurringOrder.query(on: transaction).filter(\.$user.$id == userId).first() {
                            try await existingRecurringOrder.delete(on: transaction)
                        }
                    }
                    
                    return .ok
                }
                
                static func reset(_ req: Request) async throws -> HTTPStatus {
                    let year: Int? = req.query["year"]
                    let week: Int? = req.query["week"]
                    
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    let recurringOrderExceptions = RecurringOrderException.query(on: req.db)
                        .join(WeekOrder.self, on: \RecurringOrderException.$weekOrder.$id == \WeekOrder.$id)
                        .filter(\.$user.$id == userId)
                    
                    if let year {
                        recurringOrderExceptions.filter(WeekOrder.self, \.$year == year)
                    }
                    
                    if let week {
                        recurringOrderExceptions.filter(WeekOrder.self, \.$week == week)
                    }
                    
                    try await recurringOrderExceptions.delete()
                    
                    return .ok
                }
            }
        }
    }
}
