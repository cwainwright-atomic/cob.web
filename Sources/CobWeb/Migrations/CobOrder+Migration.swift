//
//  CreateCobOrders.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Fluent

extension CobOrder {
    struct Migration: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema("cob_orders")
                .id()
                .field("user_id", .uuid, .required, .references("users", "id"))
                .field("week", .date, .required)
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .field("order_detail_filling", .string, .required)
                .field("order_detail_bread", .string, .required)
                .field("order_detail_sauce", .string, .required)
                .unique(on: "user_id")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema("cob_orders").delete()
        }
    }
}
