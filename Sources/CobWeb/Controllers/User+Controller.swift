//
//  UserController.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Vapor
import Fluent

extension User {
    struct Controller : RouteCollection {
        func boot(routes: any Vapor.RoutesBuilder) throws {
            let users = routes.grouped("users")
        
            users.post("signup", use: Self.postUser)
            
            let passwordProtected = users.grouped(User.Authenticator()).grouped(User.guardMiddleware())
            passwordProtected.post("login") { req async throws -> UserToken in
                let user = try req.auth.require(User.self)
                let token = try user.generateToken()
                try await token.save(on: req.db)
                return token
            }
        }
        
        static func getUser(req: Request) async throws -> User.Response {
            let userQuery: () async throws -> User?
            
            if let name: String = req.query["name"] {
                req.logger.info("Searching for user by name: \(name)")
                userQuery = User.query(on: req.db).filter(\.$name == name).first
            } else if let email: String = req.query["email"] {
                req.logger.info("Searching for user by email: \(email)")
                userQuery = User.query(on: req.db).filter(\.$email == email).first
            } else {
                throw Abort(.badRequest, reason: "Neither username nor email query parameter provided")
            }
            
            guard let user = try await userQuery() else { throw Abort(.notFound, reason: "User not found") }
            
            return User.Response(fromUser: user)
        }
        
        private static func postUser(req: Request) async throws -> User.Response {
            let create: User.Create
            
            do {
                create = try req.content.decode(User.Create.self)
            } catch {
                throw Abort(.badRequest, reason: "Failed to decode user data")
            }
            
            if create.password != create.confirmPassword {
                throw Abort(.badRequest, reason: "Passwords do not match")
            }
            
            let user = try User(fromCreate: create)
            
            try await user.save(on: req.db)
            
            return User.Response(fromUser: user)
        }
        
        private static func deleteUser(req: Request) async throws -> HTTPStatus {
            let userDetail = try await getUser(req: req)
            
            guard let user = try await User.query(on: req.db).filter(\.$email == userDetail.email).first() else { throw Abort(.internalServerError, reason: "Failed to locate user to delete") }
            
            try await user.delete(on: req.db)
            
            return .ok
        }
    }
}
