//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 31/08/2025.
//

import Vapor

extension User {
    struct DTO: Content {
        var name: String
        var email: String
        
        init(fromUser user: User) {
            self.name = user.name
            self.email = user.email
        }
    }
}
