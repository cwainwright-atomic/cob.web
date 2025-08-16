//
//  UserController.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Vapor
import Fluent

extension SlackUser : Content {}

struct UserController : RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        let users = routes.grouped("user")

        users.get(use: UserController.getUser)
        users.delete(use: UserController.deleteUser)
    }
    
    static func getUser(req: Request) async throws -> SlackUser {
        let userQuery: () async throws -> SlackUser?
        
        if let slackId: String = req.query["slackId"] {
            req.logger.info("Searching for user by slackId: \(slackId)")
            userQuery = SlackUser.query(on: req.db).filter(\.$slackId == slackId).first
        } else if let userId: UUID = req.query["userId"] {
            req.logger.info("Searching for user by userId: \(userId)")
            userQuery = SlackUser.query(on: req.db).filter(\._$id == userId).first
        } else {
            throw Abort(.badRequest, reason: "Neither slackId or userId query parameter provided")
        }
        
        guard let slackUser = try await userQuery() else { throw Abort(.notFound, reason: "User not found") }
        
        return slackUser
    }
    
    private static func deleteUser(req: Request) async throws -> HTTPStatus {
        let slackUser = try await getUser(req: req)
        
        try await slackUser.delete(on: req.db)
        
        return .ok
    }
}
