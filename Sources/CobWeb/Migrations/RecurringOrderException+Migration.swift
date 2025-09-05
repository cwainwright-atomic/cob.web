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
                .field("user_id", .uuid, .required, .references("users", "id"))
                .field("week_order_id", .uuid, .required, .references("week_orders", "id"))
                .field("created_at", .datetime, .required)
                .unique(on: "user_id", "week_order_id")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema(RecurringOrderException.schema).delete()
        }
    }
}
