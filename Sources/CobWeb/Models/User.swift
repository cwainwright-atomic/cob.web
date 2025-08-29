//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Fluent
import Vapor

final class User : Model, @unchecked Sendable, Content {
    static let schema = "users"
    
    init() { }
    
    init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email.lowercased()
        self.passwordHash = passwordHash
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Children(for: \.$user)
    var cob_orders: [CobOrder]
}

extension User : Authenticatable {
    struct Authenticator : AsyncBasicAuthenticator {
        func authenticate(basic: BasicAuthorization, for request: Request) async throws {
            let user = try await User.query(on: request.db).group(.or) {or in
                or.filter(\.$name == basic.username)
                or.filter(\.$email == basic.username.lowercased())
            }
                .first()
            if let user {
                if try user.verify(password: basic.password) {
                    request.auth.login(user)
                }
            }
        }
    }
    
    func authenticator() -> Authenticator {.init()}
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension User {
    struct Create: Content, Validatable {
        var name: String
        var email: String
        var password: String
        var confirmPassword: String
        
        static func validations(_ validations: inout Validations) {
            validations.add("name", as: String.self, is: .count(3...) && .alphanumeric)
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(8...))
            validations.add("confirmPassword", as: String.self, is: !.empty)
        }
    }
    
    convenience init(fromCreate create: Create) throws {
        try self.init(name: create.name, email: create.email, passwordHash: Bcrypt.hash(create.password))
    }
}

extension User {
    struct Response: Content {
        var name: String
        var email: String
        
        init(fromUser user: User) {
            name = user.name
            email = user.email.lowercased()
        }
    }
}


extension User {
    func generateToken() throws -> UserToken {
        try .init(
            value: [UInt8].random(count: 32).base64,
            userId: self.requireID()
        )
    }
}
