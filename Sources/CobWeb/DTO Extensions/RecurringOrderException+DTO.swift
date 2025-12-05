//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 10/10/2025.
//

import Crumbs
import Vapor

extension RecurringOrderExceptionDTO: @retroactive Content {}

extension RecurringOrderExceptionDTO {
    init(fromRecurringOrderException recurringOrderException: RecurringOrderException, user: UserDTO? = nil, week: WeekDTO? = nil) throws {
        self.init(id: try recurringOrderException.requireID(), createdAt: recurringOrderException.createdAt ?? Date(), user: user, week: week)
    }
}
