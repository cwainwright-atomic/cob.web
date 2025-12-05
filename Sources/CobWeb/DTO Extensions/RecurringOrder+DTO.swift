//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Crumbs
import Vapor

extension RecurringOrderDTO: @retroactive RequestDecodable {}
extension RecurringOrderDTO: @retroactive ResponseEncodable {}
extension RecurringOrderDTO: @retroactive AsyncRequestDecodable {}
extension RecurringOrderDTO: @retroactive AsyncResponseEncodable {}
extension RecurringOrderDTO : @retroactive Content {}

extension RecurringOrderDTO {
    init(from recurringOrder: RecurringOrder) throws {
        let id = try recurringOrder.requireID()
        let startDate = recurringOrder.startAt
        let orderDetail = CobOrderDetailDTO(fromDetail: recurringOrder.orderDetail)
        self.init(id: id, startDate: startDate, orderDetail: orderDetail)
    }
}

extension RecurringOrderDTO.AssociatedName: @retroactive Content {}

