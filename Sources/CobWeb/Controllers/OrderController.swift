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

struct OrderController : RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        let orders = routes.grouped("orders")
        orders.get(use: getByWeek)
        
        let userOps = orders.grouped("user", ":userId")
        userOps.get(use: getByUser)
        userOps.post(use: createByUser)
        userOps.delete(use: deleteByUser)
    }
    
    func getAllOrders(_ req: Request) async throws -> [CobOrder] {
        try await CobOrder.query(on: req.db).all()
    }
    
    func getByUser(_ req: Request) async throws -> CobOrder {
        let userId = try req.parameters.require("userId")
        
        guard let weekOrderId = try await WeekOrder.current(on: req.db, logger: req.logger)?.requireID() else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
        
        guard let cob = try await CobOrder.query(on: req.db).filter(\.$weekOrder.$id == weekOrderId).first() else { throw Abort(.notFound, reason: "No order found for user \(userId) for current week")}
        
        return cob
    }
    
    func createByUser(_ req: Request) async throws -> CobOrder {
        let userId = try req.parameters.require("userId")
        
        guard let slackUser = await SlackUser.newOrExisting(slackId: userId, on: req.db, logger: req.logger) else { throw Abort(.failedDependency, reason: "Failed to register slack user \(userId)") }
        
        guard let weekOrder = await WeekOrder.current(on: req.db, logger: req.logger) else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
        
        let orderDetail = try req.content.decode(CobOrderDetail.self)
        
        let cobOrder = CobOrder(userId: try slackUser.requireID(), orderDetail: orderDetail, weekOrderId: try weekOrder.requireID())
        try await cobOrder.save(on: req.db)
        
        return cobOrder
    }
    
    func getByWeek(_ req: Request) async throws -> [CobOrder] {
        let fallbackDateComponents = WeekOrder.dateComponents(Date())
        
        let year: Int? = req.query["year"] ??  fallbackDateComponents.year
            
        let week: Int? = req.query["week"] ?? fallbackDateComponents.week
        
        guard let weekOrderId = try await WeekOrder.current(on: req.db, logger: req.logger, week: week, year: year)?.requireID() else { throw Abort(.noContent, reason: "No order found for provided week") }
        
        return try await CobOrder.query(on: req.db).filter(\.$weekOrder.$id == weekOrderId).all()
    }
    
    func deleteByUser(_ req: Request) async throws -> HTTPStatus {
        let userId = try req.parameters.require("userId")
        
        guard let slackUser = try await SlackUser.query(on: req.db).filter(\.$slackId == userId).first()?.requireID() else { throw Abort(.notFound, reason: "No user found with slackId \(userId)") }
        
        guard let weekOrderId = try await WeekOrder.current(on: req.db, logger: req.logger)?.requireID() else { throw Abort(.notFound, reason: "Current week order could not be fetched") }
        
        guard let cobOrder = try await CobOrder.query(on: req.db).filter(\.$weekOrder.$id == weekOrderId).filter(\.$slackUser.$id == slackUser).first() else { throw Abort(.notFound, reason: "No order found for user \(userId)") }
        
        try await cobOrder.delete(on: req.db)
        
        return .ok
    }
}
