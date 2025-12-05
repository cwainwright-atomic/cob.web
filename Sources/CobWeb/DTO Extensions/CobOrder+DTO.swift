//
//  CobOrder+Content.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Vapor
import Crumbs

extension CobOrderDTO {
    init(fromOrder order: CobOrder) throws {
        self.init(
            id: try order.requireID(),
            createdAt: order.createdAt ?? Date(),
            updatedAt: order.updatedAt ?? Date(),
            orderDetail: CobOrderDetailDTO(fromDetail: order.orderDetail),
            orderKind: .single
        )
    }
        
    init(fromRecurring order: RecurringOrder) throws {
        self.init(
            id: try order.requireID(),
            createdAt: order.createdAt ?? Date(),
            updatedAt: order.updatedAt ?? Date(),
            orderDetail: CobOrderDetailDTO(fromDetail: order.orderDetail),
            orderKind: .recurring
        )
    }
}

extension CobOrderDTO: @retroactive Content {}

extension CobOrderDTO.AssociatedUser: @retroactive Content {}

extension CobOrderDTO.AssociatedWeek: @retroactive Content {}
