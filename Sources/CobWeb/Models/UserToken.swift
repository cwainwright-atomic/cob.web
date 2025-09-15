//
//  UserToken.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 29/08/2025.
//

import Foundation
import Fluent
import Vapor

public final class UserToken: Model, @unchecked Sendable {
    public static let schema = "user_tokens"
    
    public init() {}
    
    init(id: UUID? = nil, value: String, userId: User.IDValue) {
        self.id = id
        self.value = value
        self.expiry = Date(timeIntervalSinceNow: 3600)
        self.$user.id = userId
    }
    
    @ID(key: .id)
    public var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Field(key: "expiry")
    var expiry: Date
    
    @Parent(key: "user_id")
    var user: User
    
}

extension UserToken : ModelTokenAuthenticatable {
    public static var valueKey: KeyPath<UserToken, Field<String>> { \.$value }
    public static var userKey: KeyPath<UserToken, Parent<User>> { \.$user }
    
    public var isValid: Bool { expiry > Date() }
}

