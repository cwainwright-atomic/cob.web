//
//  CobOrder.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Foundation
import Fluent

public final class CobOrder : Model, @unchecked Sendable {
    public static let schema = "cob_orders"
    
    public init() {}
    
    init(id: UUID? = nil, createdAt: Date? = nil, userId: UUID, orderDetail: CobOrderDetail, weekOrderId: UUID) {
        self.id = id
        self.createdAt = createdAt
        self.orderDetail = orderDetail
        self.$user.id = userId
        self.$weekOrder.id = weekOrderId
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Group(key: "order_detail")
    var orderDetail: CobOrderDetail

    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "week_order_id")
    var weekOrder: WeekOrder
}

extension CobOrder {
    static func find(userId: UUID, weekId: UUID, includeUser: Bool = false, includeWeek: Bool = false,  on db: any Database) async throws -> CobOrder? {
        let query = CobOrder.query(on: db)
            .filter(\.$weekOrder.$id == weekId)
            .filter(\.$user.$id == userId)
        
        if includeUser {
            query.join(User.self, on: \User.$id == \CobOrder.$user.$id)
        }
        
        if includeWeek {
            query.join(WeekOrder.self, on: \WeekOrder.$id == \CobOrder.$weekOrder.$id)
        }
        
        return try await query.first()
    }
}
