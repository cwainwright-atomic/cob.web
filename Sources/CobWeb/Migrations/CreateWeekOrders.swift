//
//  CreateWeekOrders.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Foundation
import Fluent

struct CreateWeekOrders: Migration {
    func prepare(on database: any FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return database.schema("week_orders")
            .id()
            .field("week", .int8, .required)
            .field("year", .int64, .required) // lets still be ordering cobs in the year 18,446,744,073,709,551,616!
            .unique(on: "week", "year")
            .create()
    }
    
    func revert(on database: any FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return database.schema("week_orders").delete()
    }
}
