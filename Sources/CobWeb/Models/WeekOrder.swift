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
    
    
    static func dateComponents(_ now: Date) -> (week: Int, year: Int) {
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return (week: week, year: year)
    }
    
    static func current(on db: any Database, logger: Logger, week: Int? = nil, year: Int? = nil) async -> WeekOrder? {
        let calendar = Calendar(identifier: .iso8601)
        let today = Date()
        let week = week ?? calendar.component(.weekOfYear, from: today)
        let year = year ?? calendar.component(.yearForWeekOfYear, from: today)
        do {
            if let currentWeek = try await WeekOrder.query(on: db)
                .filter(\.$week == week)
                .filter((\.$year == year))
                .first() {
                
                logger.info("Week already exists")
                return currentWeek
            } else {
                let newWeek = WeekOrder(datetime: today)
                
                try await newWeek.save(on: db)
                logger.info("New week created")
                return newWeek
            }
        } catch {
            logger.warning("Week creation failed: \(error.localizedDescription)")
            return nil
        }
    }
}
