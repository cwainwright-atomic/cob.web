//
//  CobOrder+Content.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Vapor
import Crumbs

extension CobOrderDTO {
    init(fromOrder order: CobOrder, user: UserDTO? = nil, weekOrder: WeekOrderDTO? = nil) throws {
        self.init(id: try order.requireID(), createdAt: order.createdAt ?? Date(), orderDetail: CobOrderDetailDTO(fromDetail: order.orderDetail), orderKind: .single, user: user, weekOrder: weekOrder)
    }
        
    init(fromRecurring order: RecurringOrder, user: UserDTO? = nil, weekOrder: WeekOrderDTO? = nil) throws {
        self.init(id: try order.requireID(), createdAt: Date(), orderDetail: CobOrderDetailDTO(fromDetail: order.orderDetail), orderKind: .recurring, user: user, weekOrder: weekOrder)
    }
}

extension CobOrderDTO: @retroactive RequestDecodable {}
extension CobOrderDTO: @retroactive ResponseEncodable {}
extension CobOrderDTO: @retroactive AsyncRequestDecodable {}
extension CobOrderDTO: @retroactive AsyncResponseEncodable {}
extension CobOrderDTO: @retroactive Content {}
