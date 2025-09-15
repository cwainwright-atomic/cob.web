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
    init(fromRecurringOrder recurringOrder: RecurringOrder) async throws {
        self.init(orderDetail: CobOrderDetailDTO(fromDetail: recurringOrder.orderDetail))
    }
}
