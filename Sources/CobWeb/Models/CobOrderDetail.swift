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
    
    init(from dto: CobOrderDetailDTO) {
        self.filling = dto.filling
        self.bread = dto.bread
        self.sauce = dto.sauce
    }
    
    @Enum(key: "filling")
    var filling: Filling
    
    @Enum(key: "bread")
    var bread: Bread
    
    @Enum(key: "sauce")
    var sauce: Sauce
}
