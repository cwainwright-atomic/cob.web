//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Fluent

struct CreateSlackUsers: Migration {
    func prepare(on database: any FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return database.schema("slack_users")
            .id()
            .field("slack_id", .string, .required)
            .field("name", .string)
            .unique(on: "slack_id")
            .create()
    }
    
    func revert(on database: any FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        return database.schema("slack_users").delete()
    }
}

