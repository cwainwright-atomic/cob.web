//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Crumbs
import Vapor

extension UserDTO: @retroactive RequestDecodable {}
extension UserDTO: @retroactive ResponseEncodable {}
extension UserDTO: @retroactive AsyncRequestDecodable {}
extension UserDTO: @retroactive AsyncResponseEncodable {}
extension UserDTO: @retroactive Content {}

extension UserDTO {
    init(fromUser user: User) {
        self.init(name: user.name, email: user.email)
    }
}

extension TokenDTO: @retroactive RequestDecodable {}
extension TokenDTO: @retroactive ResponseEncodable {}
extension TokenDTO: @retroactive AsyncRequestDecodable {}
extension TokenDTO: @retroactive AsyncResponseEncodable {}
extension TokenDTO: @retroactive Content {}

extension TokenDTO {
    init(fromToken token: UserToken) {
        self.init(value: token.value, expiry: token.expiry)
    }
}

extension UserTokenDTO: @retroactive RequestDecodable {}
extension UserTokenDTO: @retroactive ResponseEncodable {}
extension UserTokenDTO: @retroactive AsyncRequestDecodable {}
extension UserTokenDTO: @retroactive AsyncResponseEncodable {}
extension UserTokenDTO : @retroactive Content {}

extension UserTokenDTO {
    init(fromUser user: User, userToken: UserToken) {
        let userDTO = UserDTO(fromUser: user)
        let tokenDTO = TokenDTO(fromToken: userToken)
        self.init(token: tokenDTO, user: userDTO)
    }
}
