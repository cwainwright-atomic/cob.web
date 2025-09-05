//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 30/08/2025.
//

import Foundation

import Vapor
import Fluent

extension RecurringOrder {
    struct Migrtaion: AsyncMigration {
        func prepare(on database: any Database) async throws {
            try await database.schema("recurring_orders")
                .id()
                .field("user_id", .uuid, .required, .references("users", "id"))
                .field("order_detail_filling", .string, .required)
                .field("order_detail_bread", .string, .required)
                .field("order_detail_sauce", .string, .required)
                .field("created_at", .datetime, .required)
                .unique(on: "user_id")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema("recurring_orders").delete()
        }
    }
}
