//
//  CreateCobOrders.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Fluent

struct CreateCobOrders: Migration {
    func prepare(on database: any FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return database.schema("cob_orders")
            .id()
            .field("created_at", .datetime, .required)
            .field("slack_user_id", .uuid, .required, .references("slack_users", "id"))
            .field("week_order_id", .uuid, .required, .references("week_orders", "id"))
            .field("order_detail_filling", .string, .required)
            .field("order_detail_bread", .string, .required)
            .field("order_detail_sauce", .string, .required)
            .unique(on: "slack_user_id", "week_order_id")
            .create()
    }
    
    func revert(on database: any FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return database.schema("cob_orders").delete()
    }
}
