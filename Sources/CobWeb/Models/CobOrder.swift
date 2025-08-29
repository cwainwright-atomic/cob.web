//
//  CobOrder.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Foundation
import Fluent

final class CobOrder : Model, @unchecked Sendable {
    static let schema = "cob_orders"
    
    init() {}
    
    init(id: UUID? = nil, createdAt: Date? = nil, userId: UUID, orderDetail: CobOrderDetail, weekOrderId: UUID) {
        self.id = id
        self.createdAt = createdAt
        self.$user.id = userId
        self.orderDetail = orderDetail
        self.$weekOrder.id = weekOrderId
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Group(key: "order_detail")
    var orderDetail: CobOrderDetail

    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "week_order_id")
    var weekOrder: WeekOrder
}
