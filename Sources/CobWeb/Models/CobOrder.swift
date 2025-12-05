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
    
    init(id: UUID? = nil, week: Date, createdAt: Date? = nil, updatedAt: Date? = nil, orderDetail: CobOrderDetail, userId: UUID) {
        self.id = id
        self.week = week
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.orderDetail = orderDetail
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
    
    @Group(key: "order_detail")
    var orderDetail: CobOrderDetail
    
    @Parent(key: "user_id")
    var user: User
    
}
