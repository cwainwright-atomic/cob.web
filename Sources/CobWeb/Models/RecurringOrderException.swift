//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Foundation
import Fluent

final class RecurringOrderException: Model, @unchecked Sendable {
    static let schema: String = "recurring_order_exceptions"
    
    init() {}
    
    init(user: User, weekOrder: WeekOrder) throws {
        let userId = try user.requireID()
        let weekOrderId = try weekOrder.requireID()
    
        self.$user.id = userId
        self.$weekOrder.id = weekOrderId
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "week_order_id")
    var weekOrder: WeekOrder
}

extension RecurringOrderException {
    private static func get(userId: UUID, weekOrderId: UUID, on db: any Database) async throws -> QueryBuilder<RecurringOrderException> {
        let query = RecurringOrderException.query(on: db)
        
        return query
            .filter(\.$weekOrder.$id == weekOrderId)
            .filter(\.$user.$id == userId)
    }
    
    static func find(for userId: UUID, weekOrderId: UUID, on db: any Database) async throws -> RecurringOrderException? {
        try await RecurringOrderException.get(userId: userId, weekOrderId: weekOrderId, on: db).first()
    }
    
    static func exists(for userId: UUID, weekOrderId: UUID, on db: any Database) async throws -> Bool {
        try await RecurringOrderException.get(userId: userId, weekOrderId: weekOrderId, on: db).count() != 0
    }
}
