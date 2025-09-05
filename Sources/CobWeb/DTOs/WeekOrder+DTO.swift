//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Vapor

extension WeekOrder {
    struct DTO: Content {
        var week: Int
        var year: Int
        
        init(fromWeekOrder weekOrder: WeekOrder) {
            self.week = weekOrder.week
            self.year = weekOrder.year
        }
    }
    
    struct OrderDTO: Content {
        var week: Int
        var year: Int
        var orders: [CobOrder.DTO]
    }
}
