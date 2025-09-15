//
//  CobOrderDetail.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Foundation
import Fluent
import Crumbs

public final class CobOrderDetail: Fields, @unchecked Sendable {
    
    public init() {}
    
    @Enum(key: "filling")
    var filling: Filling
    
    @Enum(key: "bread")
    var bread: Bread
    
    @Enum(key: "sauce")
    var sauce: Sauce
}
