//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Fluent

extension User {
    struct Migration: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema("users")
                .id()
                .field("name", .string, .required)
                .field("email", .string, .required)
                .field("password_hash", .string, .required)
                .unique(on: "name")
                .unique(on: "email")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema("users").delete()
        }
    }
    
}
