//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Foundation
import Fluent

extension RecurringOrderException {
    struct Migration: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema(RecurringOrderException.schema)
                .id()
                .field("week", .date, .required)
                .field("user_id", .uuid, .required, .references("users", "id"))
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .unique(on: "user_id")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(RecurringOrderException.schema).delete()
        }
    }
}
