//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Foundation
import Fluent

public final class RecurringOrderException: Model, @unchecked Sendable {
    public static let schema: String = "recurring_order_exceptions"
    
    public init() {}
    
    public init(week: Date, userId: UUID) {
        self.week = week
        self.$user.id = userId
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: "week")
    var week: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Parent(key: "user_id")
    var user: User
}
