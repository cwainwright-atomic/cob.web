//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Vapor
import Fluent

extension RecurringOrder {
    struct DTO : Content {
        var orderDetail: CobOrderDetail
        var user: User.DTO?
        
        init(fromRecurringOrder recurringOrder: RecurringOrder, includeUser: Bool = false, on db: any Database) async throws {
            self.orderDetail = recurringOrder.orderDetail
            
            if includeUser {
                self.user = User.DTO(fromUser: try await recurringOrder.$user.get(on: db))
            } else {
                self.user = nil
            }
        }
    }
}
