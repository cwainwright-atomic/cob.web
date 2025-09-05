//
//  WeekOrder.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Foundation
import Fluent

final class WeekOrder : Model, @unchecked Sendable {
    
    static let schema = "week_orders"
    
    init() {}
    
    init(week: Int, year: Int) {
        self.week = week
        self.year = year
    }
    
    convenience init(datetime: Date) {
        let (week, year) = WeekOrder.dateComponents(datetime)
        
        self.init(week: week, year: year)
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "week")
    var week: Int
    
    @Field(key: "year")
    var year: Int
    
    @Children(for: \.$weekOrder)
    var cob_orders: [CobOrder]
    
    @Children(for: \.$weekOrder)
    var recurring_exceptions: [RecurringOrderException]
}

extension WeekOrder : CustomStringConvertible {
    var description: String {
        "\(year) - \(week)"
    }
}

extension WeekOrder {
    func isCurrentWeek() -> Bool {
        let (week, year) = WeekOrder.dateComponents(Date())
        return self.week == week && self.year == year
    }
    
    func orderPlaced(by user: User, includeUser: Bool = false, includeWeek: Bool = false, on db: any Database) async throws -> CobOrderVariant? {
        let weekOrderId = try self.requireID()
        let userId = try user.requireID()
        
        if let cobOrder = try await CobOrder.find(userId: userId, weekId: weekOrderId, includeUser: includeUser, includeWeek: includeWeek, on: db) {
            return .single(cobOrder)
        } else if
            let recurringOrder = try await RecurringOrder.find(for: userId, includeUser: includeUser, on: db),
            try await !RecurringOrderException.exists(for: userId, weekOrderId: weekOrderId, on: db) {
            return .recurring(recurringOrder)
        } else {
            return nil
        }
    }
}

extension WeekOrder {
    static func dateComponents(_ now: Date) -> (week: Int, year: Int) {
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return (week: week, year: year)
    }
    
    static func find(on db: any Database, week: Int? = nil, year: Int? = nil) async throws -> WeekOrder? {
        let calendar = Calendar(identifier: .iso8601)
        let today = Date()
        let week = week ?? calendar.component(.weekOfYear, from: today)
        let year = year ?? calendar.component(.yearForWeekOfYear, from: today)
        return try await WeekOrder.query(on: db)
            .filter(\.$week == week)
            .filter((\.$year == year))
            .first()
    }
    
    static func findOrCreate(on db: any Database, week: Int? = nil, year: Int? = nil) async throws -> WeekOrder? {
        let calendar = Calendar(identifier: .iso8601)
        let today = Date()
        let week = week ?? calendar.component(.weekOfYear, from: today)
        let year = year ?? calendar.component(.yearForWeekOfYear, from: today)
        if let weekOrder = try await WeekOrder.find(on: db, week: week, year: year) {
            return weekOrder
        } else {
            let weekOrder = WeekOrder(week: week, year: year)
            try await weekOrder.save(on: db)
            return weekOrder
        }
    }
}
