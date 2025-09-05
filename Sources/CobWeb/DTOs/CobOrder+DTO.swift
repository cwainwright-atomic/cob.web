//
//  CobOrder+Content.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Vapor
import Fluent

extension CobOrder {
    struct DTO: Content {
        let id: UUID
        let createdAt: Date
        let orderDetail: CobOrderDetail
        let orderKind: CobOrderKind
        let user: User.DTO?
        let weekOrder: WeekOrder.DTO?
        
        init(fromOrder order: CobOrder, user: User.DTO? = nil, weekOrder: WeekOrder.DTO? = nil) throws {
            self.id = try order.requireID()
            self.createdAt = order.createdAt ?? Date()
            self.orderDetail = order.orderDetail
            self.orderKind = .single
            self.user = user
            self.weekOrder = weekOrder
        }
        
        init(fromRecurring order: RecurringOrder, user: User.DTO? = nil, weekOrder: WeekOrder.DTO? = nil) throws {
            self.id = try order.requireID()
            self.createdAt = Date()
            self.orderDetail = order.orderDetail
            self.orderKind = .recurring
            self.user = user
            self.weekOrder = weekOrder
        }
    }
}
