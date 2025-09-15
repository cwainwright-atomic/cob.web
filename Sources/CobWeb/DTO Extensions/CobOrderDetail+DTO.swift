//
//  CobOrderDetailDTO+Vapor.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 06/09/2025.
//

import Crumbs
import Vapor

extension CobOrderDetailDTO: @retroactive RequestDecodable {}
extension CobOrderDetailDTO: @retroactive ResponseEncodable {}
extension CobOrderDetailDTO: @retroactive AsyncRequestDecodable {}
extension CobOrderDetailDTO: @retroactive AsyncResponseEncodable {}
extension CobOrderDetailDTO: @retroactive Content {}

extension CobOrderDetailDTO {
    init(fromDetail detail: CobOrderDetail) {
        self.init(filling: detail.filling, bread: detail.bread, sauce: detail.sauce)
    }
}
