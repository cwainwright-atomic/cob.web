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
            orders.get(use: Public.get)
            
            //MARK: Authenticated Endpoints
            let personal = orders
                .grouped("me")
                .grouped(UserToken.authenticator())
            
            personal.get(use: Personal.Single.get)
            personal.post(use: Personal.Single.post)
            personal.delete(use: Personal.Single.delete)
            
            personal.get("history", use: Personal.history)
            
            //MARK: Recurring Orders Endpoints
            let recurring = personal.grouped("recurring")
            recurring.get(use: Personal.Recurring.get)
            recurring.post(use: Personal.Recurring.post)
            recurring.delete(use: Personal.Recurring.delete)
            recurring.post("except", use: Personal.Recurring.Exception.post)
            recurring.delete("except", use: Personal.Recurring.Exception.delete)
        }
        
        struct Public {
            static func get(_ req: Request) async throws -> WeekDTO.WeeklyOrderDTO {
                let fallbackDateComponents = WeekDTO(from: .now)
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                
                guard let weekDate = WeekDTO(week: week, year: year).date
                else { throw Abort(.failedDependency, reason: "Start date could not be synthesised for week (\(year) - \(week))") }
                
                let weekCobOrders: [CobOrder] = try await CobOrder.query(on: req.db)
                    .join(parent: \CobOrder.$user)
                    .filter(\.$week == weekDate).all()
                
                let recurringCobOrders: [RecurringOrder] = try await RecurringOrder.query(on: req.db)
                    .join(parent: \RecurringOrder.$user).all()
                
                let exceptionCobOrders: [RecurringOrderException] = try await RecurringOrderException.query(on: req.db)
                    .join(parent: \RecurringOrderException.$user)
                    .filter(\.$week == weekDate).all()
                
                var orders: [UUID : CobOrderDTO.AssociatedName] = [:]
                
                try recurringCobOrders.forEach {
                    let user = try $0.joined(User.self)
                    let cobOrderDTO = try CobOrderDTO(fromRecurring: $0).withAssociatedName(user.name)
                    orders[try user.requireID()] = cobOrderDTO
                }
                
                try exceptionCobOrders.forEach {
                    let user = try $0.joined(User.self)
                    try orders.removeValue(forKey: user.requireID())
                }
                
                try weekCobOrders.forEach {
                    let user = try $0.joined(User.self)
                    let cobOrderDTO = try CobOrderDTO(fromOrder: $0).withAssociatedName(user.name)
                    orders[try user.requireID()] = cobOrderDTO
                }
                
                return WeekDTO.WeeklyOrderDTO(week: WeekDTO(week: week, year: year), namedOrders: Array(orders.values))
            }
        }
        
        struct Personal {
            struct Single {
                static func get(_ req: Request) async throws -> CobOrderDTO.AssociatedWeek {
                    let fallbackDateComponents = WeekDTO.current
                    let year: Int = req.query["year"] ?? fallbackDateComponents.year
                    let week: Int = req.query["week"] ?? fallbackDateComponents.week
                    
                    let user = try req.auth.require(User.self)
                    
                    guard let userId = try? user.requireID()
                    else { throw Abort(.internalServerError, reason: "User ID not found!") }
                    
                    let weekDTO = WeekDTO(week: week, year: year)
                    
                    guard let weekDate = weekDTO.date
                    else { throw Abort(.failedDependency, reason: "Start date could not be synthesised for week (\(year) - \(week))") }
                    
                    let cobOrder = try await CobOrder.query(on: req.db)
                        .filter(\CobOrder.$week == weekDate)
                        .filter(\CobOrder.$user.$id == userId)
                        .first()
                    
                    let orderException = try await RecurringOrderException.query(on: req.db)
                        .filter(\RecurringOrderException.$week == weekDate)
                        .filter(\RecurringOrderException.$user.$id == userId)
                        .first()
                    
                    let recurringOrder = try await RecurringOrder.query(on: req.db)
                        .filter(\RecurringOrder.$user.$id == userId)
                        .first()
                        
                    if let cobOrder {
                        req.logger.info("Returning single order for \(user.name) on week \(weekDate)")
                        return try CobOrderDTO(fromOrder: cobOrder).withAssociatedWeek(weekDTO)
                    } else if orderException != nil {
                        req.logger.info("Returning order exception for \(user.name) on week \(weekDate)")
                        throw Abort(.gone, reason: "Recurring order exception is in place for week \(weekDate)")
                    } else if let recurringOrder {
                        req.logger.info("Returning recurring order for \(user.name) on week \(weekDate)")
                        return try CobOrderDTO(fromRecurring: recurringOrder).withAssociatedWeek(weekDTO)
                    } else {
                        throw Abort(.notFound, reason: "No order found for user \(user.name) for week \(weekDate)")
                    }
                }
                
                static func post(_ req: Request) async throws -> CobOrderDTO.AssociatedWeek {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    let fallbackDateComponents = WeekDTO.current
                    let year: Int = req.query["year"] ??  fallbackDateComponents.year
                    let week: Int = req.query["week"] ?? fallbackDateComponents.week
                    
                    let orderDetail = try req.content.decode(CobOrderDetail.self)
                    
                    let weekDTO = WeekDTO(week: week, year: year)
                    
                    guard let weekDate = weekDTO.date
                    else { throw Abort(.failedDependency, reason: "Start date could not be synthesised for week (\(year) - \(week))") }
                    
                    return try await req.db.transaction { transaction in
                        let existingCobOrder = try await CobOrder.query(on: transaction)
                            .filter(\.$week == weekDate)
                            .filter(\.$user.$id == userId)
                            .first()
                        
                        let cobOrder: CobOrderDTO;
                        if let existingCobOrder {
                            existingCobOrder.orderDetail = orderDetail
                            try await existingCobOrder.update(on: transaction)
                            req.logger.info("Existing cob order updated")
                            cobOrder = try CobOrderDTO(fromOrder: existingCobOrder)
                        } else {
                            let newCobOrder = CobOrder(week: weekDate, orderDetail: orderDetail, userId: userId)
                            try await newCobOrder.save(on: transaction)
                            cobOrder = try CobOrderDTO(fromOrder: newCobOrder)
                        }
                        
                        return cobOrder.withAssociatedWeek(weekDTO)
                    }
                }
                
                static func delete(_ req: Request) async throws -> HTTPStatus {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    if let uuid = (req.query["id"].flatMap { UUID.init(uuidString: $0) }) {
                        try await req.db.transaction { transaction in
                            guard let order = try await CobOrder.query(on: transaction).filter(\.$id == uuid).with(\.$user).first()
                            else { throw Abort(.notFound, reason: "No order found for id \(uuid.uuidString)") }
                            
                            guard order.user.id == userId
                            else { throw Abort(.notFound, reason: "You do not have permission to delete this order.") }
                            
                            try await order.delete(on: transaction)
                        }
                        
                        req.logger.info("Order \(uuid.uuidString) deleted by \(user.name)")
                        
                        return .ok
                    }
                    
                    if let week: Int = req.query["week"].flatMap(Int.init(bitPattern:)),
                       let year: Int = req.query["year"].flatMap(Int.init(bitPattern:)),
                       let weekDate = WeekDTO(week: week, year: year).date {
                        try await req.db.transaction { transaction in
                            guard let order = try await CobOrder.query(on: transaction).filter(\.$week == weekDate).filter(\.$user.$id == userId).first()
                            else { throw Abort(.notFound, reason: "No order found for week \(WeekDTO(week: week, year: year))") }
                            
                            try await order.delete(on: transaction)
                        }
                        
                        req.logger.info("Order \(WeekDTO(week: week, year: year)) deleted by \(user.name)")
                        return .ok
                    }
                    
                    throw Abort(.badRequest, reason: "Invalid or missing 'id' or 'week' and 'year' query parameters. Expected valid UUID string or week/year Integers.")
                }
            }
            
            /// Get paginated history of a users cob orders
            /// Page sizes are 10, page index can be configured a url parameter
            static func history(_ req: Request) async throws -> [WeekDTO.AssociatedOrderDTO] {
                let user = try req.auth.require(User.self)
                let userId = try user.requireID()
                
                let pageIndex: Int = req.query["page"] ?? 0
                
                let fallbackDateComponents = WeekDTO.current
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                let weekDTO = WeekDTO(week: week, year: year)
                
                guard
                    let weekDate = weekDTO.date,
                    let changeover = WeekDTO.changeoverTime(from: weekDate)
                else { throw Abort(.internalServerError, reason: "Could not get current week date time") }
                
                let high = 10 * (pageIndex + 1)
                let low = 10 * pageIndex + 1
                
                let weeks = (low...high)
                    .compactMap { Calendar(identifier: .iso8601).date(byAdding: .weekOfMonth, value: -$0, to: changeover) }
                    .compactMap { WeekDTO(from: $0) }
                
                guard
                    let upper = Calendar(identifier: .iso8601).date(byAdding: .weekOfMonth, value: -low, to: changeover),
                    let lower = Calendar(identifier: .iso8601).date(byAdding: .weekOfMonth, value: -high, to: changeover)
                else { throw Abort(.internalServerError, reason: "Could not get date bounds for pagination") }
                
                let orders = try await CobOrder.query(on: req.db)
                    .filter(\.$user.$id == userId)
                    .group(.and) { and in
                        and.filter(\.$week, .greaterThan, lower)
                        and.filter(\.$week, .lessThanOrEqual, upper)
                    }
                    .all()
                
                let orderExceptions = try await RecurringOrderException.query(on: req.db)
                    .filter(\.$user.$id == userId)
                    .group(.and) { and in
                        and.filter(\.$week, .greaterThan, lower)
                        and.filter(\.$week, .lessThanOrEqual, upper)
                    }
                    .all()
                
                let recurringOrder = try await RecurringOrder.query(on: req.db)
                    .filter(\.$user.$id == userId)
                    .first()
                
                let weekOrders: [WeekDTO.AssociatedOrderDTO] = weeks
                    .map { week in
                        if let singleOrder = orders.first(where: { WeekDTO(from: $0.week) == week }) {
                            return week.withAssociatedOrder(.single(CobOrderDetailDTO(fromDetail: singleOrder.orderDetail)))
                        }
                        
                        if orderExceptions.contains(where: { WeekDTO(from: $0.week) == week }) {
                            return week.withAssociatedOrder(.exception)
                        }
                        
                        if let recurringOrder {
                            let dto = CobOrderDetailDTO(fromDetail: recurringOrder.orderDetail)
                            
                            
                            let order: CobOrderVariantDTO? = if let weekStart = week.date {
                                recurringOrder.startAt <= weekStart ? .recurring(dto) : nil
                            } else {
                                .recurring(CobOrderDetailDTO(fromDetail: recurringOrder.orderDetail))
                            }
                            return week.withAssociatedOrder(order)
                        }
                        
                        return week.withAssociatedOrder(nil)
                    }
                
                return weekOrders
            }
            
            struct Recurring {
                static func get(_ req: Request) async throws -> RecurringOrderDTO.AssociatedName {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    guard let recurringOrder = try await RecurringOrder.query(on: req.db)
                        .filter(\.$user.$id == userId)
                        .first()
                    else { throw Abort(.notFound, reason: "No recurring order found for user \(user.name)") }
                    
                    return try RecurringOrderDTO(from: recurringOrder).withAssociatedName(user.name)
                }
                
                static func post(_ req: Request) async throws -> RecurringOrderDTO.AssociatedName {
                    let fallbackDateComponents = WeekDTO.current
                    let year: Int = req.query["year"] ?? fallbackDateComponents.year
                    let week: Int = req.query["week"] ?? fallbackDateComponents.week
                    
                    let weekDTO = WeekDTO(week: week, year: year)
                    
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()

                    let orderDetail = CobOrderDetail(from: try req.content.decode(CobOrderDetailDTO.self))
                    
                    return try await req.db.transaction { transaction in
                        if let existingRecurringOrder = try await RecurringOrder.query(on: transaction)
                            .filter(\.$user.$id == userId)
                            .first()
                        {
                            if let weekDay = weekDTO.date {
                                existingRecurringOrder.startAt = weekDay
                            }
                            existingRecurringOrder.orderDetail = orderDetail
                            try await existingRecurringOrder.update(on: transaction)
                            return try RecurringOrderDTO(from: existingRecurringOrder).withAssociatedName(user.name)
                        } else {
                            let weekDate = weekDTO.date ?? .distantPast
                            let newRecurringOrder = RecurringOrder(userId: userId, startAt: weekDate, orderDetail: orderDetail)
                            try await newRecurringOrder.save(on: transaction)
                            return try RecurringOrderDTO(from: newRecurringOrder).withAssociatedName(user.name)
                        }
                    }
                }
                
                static func delete(_ req: Request) async throws -> HTTPStatus {
                    let user = try req.auth.require(User.self)
                    let userId = try user.requireID()
                    
                    try await req.db.transaction { transaction in
                        guard let recurringOrder = try await RecurringOrder.query(on: transaction)
                            .filter(\.$user.$id == userId)
                            .first()
                        else { throw Abort(.notFound, reason: "No recurring order found") }
                        
                        try await recurringOrder.delete(on: transaction)
                    }
                    
                    return .ok
                }
                
                struct Exception {
                    static func post(_ req: Request) async throws -> RecurringOrderExceptionDTO {
                        let fallbackDateComponents = WeekDTO.current
                        let year: Int = req.query["year"] ?? fallbackDateComponents.year
                        let week: Int = req.query["week"] ?? fallbackDateComponents.week
                        
                        let user = try req.auth.require(User.self)
                        let userId = try user.requireID()
                        
                        let userDTO = UserDTO(fromUser: user)
                        let weekDTO = WeekDTO(week: week, year: year)
                        
                        guard let weekDate = weekDTO.date
                        else { throw Abort(.failedDependency, reason: "Start date could not be synthesised for week (\(year) - \(week))") }
                        
                        let orderException = try await req.db.transaction { transaction in
                            let existingException = try await RecurringOrderException.query(on: transaction)
                                .filter(\.$week == weekDate)
                                .filter(\.$user.$id == userId)
                                .first()
                            
                            guard existingException == nil
                            else { throw Abort(.conflict, reason: "Exception already exists") }
                            
                            let orderException = RecurringOrderException(week: weekDate, userId: userId)
                            try await orderException.save(on: transaction)
                            return orderException
                        }
                        
                        return try RecurringOrderExceptionDTO(
                            fromRecurringOrderException: orderException,
                            user: userDTO,
                            week: weekDTO
                        )
                    }
                    
                    static func delete(_ req: Request) async throws -> HTTPStatus {
                        guard let uuid = (req.query["id"].flatMap { UUID.init(uuidString: $0) })
                        else { throw Abort(.badRequest, reason: "Invalid or missing 'id' query parameter. Expected valid UUID string.") }

                        let user = try req.auth.require(User.self)
                        let userId = try user.requireID()
                                                
                        try await req.db.transaction { transaction in
                            guard let recurringOrderException = try await RecurringOrderException
                                .query(on: transaction)
                                .filter(\.$id == uuid)
                                .with(\.$user).first()
                            else { throw Abort(.notFound, reason: "No exception found for id \(uuid.uuidString)") }
                            
                            guard try recurringOrderException.joined(User.self).requireID() == userId
                            else { throw Abort(.notFound, reason: "You do not have permission to delete this order.") }
                            
                            try await recurringOrderException.delete(on: transaction)
                        }
                        
                        return .ok
                    }
                }
            }
        }
    }
}

