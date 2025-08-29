//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Vapor
import Fluent

extension CobOrder: Content {}

extension CobOrder {
    struct Controller : RouteCollection {
        func boot(routes: any Vapor.RoutesBuilder) throws {
            let orders = routes.grouped("orders")
            
            //MARK: Public Endpoint
            orders.get(use: PerWeek.get)
            
            //MARK: Authenticated Endpoints
            let tokenProtected = orders
                .grouped("me")
                .grouped(UserToken.authenticator())
            tokenProtected.get(use: PerUser.get)
            tokenProtected.post(use: PerUser.post)
            tokenProtected.delete(use: PerUser.delete)
            tokenProtected.get("history", use: PerUser.history)
        }
        
        struct PerWeek {
            static func get(_ req: Request) async throws -> [CobOrder] {
                let fallbackDateComponents = WeekOrder.dateComponents(Date())
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                let pageIndex: Int = req.query["page"] ?? 0
                
                guard let weekOrderId = try await WeekOrder.query(on: req.db).filter(\.$week == week).filter(\.$year == year).first()?.requireID() else { throw Abort(.noContent, reason: "No order found for provided week (\(year) - \(week))") }
                
                return try await CobOrder.query(on: req.db).filter(\.$weekOrder.$id == weekOrderId).page(withIndex: pageIndex, size: 10).items
            }
        }
        
        struct PerUser {
            static func get(_ req: Request) async throws -> CobOrder {
                let fallbackDateComponents = WeekOrder.dateComponents(Date())
                let year: Int = req.query["year"] ??  fallbackDateComponents.year
                let week: Int = req.query["week"] ?? fallbackDateComponents.week
                
                let userId = try req.auth.require(User.self).requireID()
                
                guard let weekOrderId = try await WeekOrder.current(on: req.db, logger: req.logger)?.requireID() else { throw Abort(.notFound, reason: "Week order (\(year) - \(week)) could not be fetched") }
                
                guard let cob = try await CobOrder.query(on: req.db).filter(\.$weekOrder.$id == weekOrderId).first() else { throw Abort(.notFound, reason: "No order found for user \(userId) for current week")}
                
                return cob
            }
            
            static func post(_ req: Request) async throws -> CobOrder {
                let userId = try req.auth.require(User.self).requireID()
                
                guard let weekOrder = await WeekOrder.current(on: req.db, logger: req.logger) else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
                
                let orderDetail = try req.content.decode(CobOrderDetail.self)
                
                let cobOrder = CobOrder(userId: userId, orderDetail: orderDetail, weekOrderId: try weekOrder.requireID())
                try await cobOrder.save(on: req.db)
                
                return cobOrder
            }
            
            static func delete(_ req: Request) async throws -> HTTPStatus {
                let userId = try req.auth.require(User.self).requireID()
                
                guard let weekOrderId = try await WeekOrder.current(on: req.db, logger: req.logger)?.requireID() else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
                
                guard let cobOrder = try await CobOrder.query(on: req.db).filter(\.$weekOrder.$id == weekOrderId).filter(\.$user.$id == userId).first() else { throw Abort(.notFound, reason: "No order found for user \(userId)") }
                
                try await cobOrder.delete(on: req.db)
                
                return .ok
            }
            
            static func history(_ req: Request) async throws -> [CobOrder] {
                let userId = try req.auth.require(User.self).requireID()
                
                let pageIndex: Int = req.query["page"] ?? 0
                
                return try await CobOrder.query(on: req.db).filter(\.$user.$id == userId).sort( \.$createdAt, .descending).page(withIndex: pageIndex, size: 10).items
            }
        }
    }
}
