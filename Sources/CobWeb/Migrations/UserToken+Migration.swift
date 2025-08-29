//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 29/08/2025.
//

import Foundation
import Fluent
import Vapor

extension UserToken {
    struct Migration: AsyncMigration {
        var name: String { "user_tokens" }
        
        func prepare(on database: any Database) async throws {
            try await database.schema("user_tokens")
                .id()
                .field("value", .string, .required)
                .field("user_id", .string, .required, .references("users", "id"))
                .field("expiry", .datetime, .required)
                .unique(on: "value")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema("user_tokens").delete()
        }
    }
}
