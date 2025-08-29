//
//  UserToken.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 29/08/2025.
//

import Foundation
import Fluent
import Vapor

final class UserToken: Model, Content, @unchecked Sendable {
    static let schema = "user_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Field(key: "expiry")
    var expiry: Date
    
    @Parent(key: "user_id")
    var user: User
    
    init() {}
    
    init(id: UUID? = nil, value: String, userId: User.IDValue) {
        self.id = id
        self.value = value
        self.expiry = Date(timeIntervalSinceNow: 3600)
        self.$user.id = userId
    }
}

extension UserToken : ModelTokenAuthenticatable {
    static var valueKey: KeyPath<UserToken, Field<String>> { \.$value }
    static var userKey: KeyPath<UserToken, Parent<User>> { \.$user }
    
    var isValid: Bool { expiry > Date() }
}
