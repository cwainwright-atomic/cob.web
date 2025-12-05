//
//  RecurringOrder.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 30/08/2025.
//

import Foundation
import Fluent

public final class RecurringOrder: Model, @unchecked Sendable {
    public static let schema = "recurring_orders"
    
    public init() {}
    
    init(userId: UUID, startAt: Date, orderDetail: CobOrderDetail) {
        self.$user.id = userId
        self.startAt = startAt
        self.orderDetail = orderDetail
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: "week")
    var startAt: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Group(key: "order_detail")
    var orderDetail: CobOrderDetail
    
    @Parent(key: "user_id")
    var user: User
}

extension RecurringOrder {
    static func find(for userId: UUID, includeUser: Bool = false, on db: any Database) async throws -> RecurringOrder? {
        
        let query = RecurringOrder.query(on: db)
            .filter(\.$user.$id == userId)
        
        if includeUser {
            query.join(User.self, on: \User.$id == \RecurringOrder.$user.$id)
        }
        
        return try await query.first()
    }
}
