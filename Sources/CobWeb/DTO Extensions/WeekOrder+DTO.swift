//
//  WeekOrder+DTO.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Crumbs
import Vapor

//extension WeekDTO: @retroactive RequestDecodable {}
//extension WeekDTO: @retroactive ResponseEncodable {}
//extension WeekDTO: @retroactive AsyncRequestDecodable {}
//extension WeekDTO: @retroactive AsyncResponseEncodable {}
extension WeekDTO : @retroactive Content {}

extension WeekDTO.AssociatedOrderDTO: @retroactive Content {}

//extension WeekOrderDTO: @retroactive RequestDecodable {}
//extension WeekOrderDTO: @retroactive ResponseEncodable {}
//extension WeekOrderDTO: @retroactive AsyncRequestDecodable {}
//extension WeekOrderDTO: @retroactive AsyncResponseEncodable {}
extension WeekDTO.WeeklyOrderDTO: @retroactive Content {}
