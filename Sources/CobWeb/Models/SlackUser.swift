//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 16/08/2025.
//

import Foundation
import Fluent

final class SlackUser : Model, @unchecked Sendable {
    static let schema = "slack_users"
    
    init() { }
    
    init(id: UUID? = nil, slackId: String, name: String? = nil) {
        self.id = id
        self.slackId = slackId
        self.name = name
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "slack_id")
    var slackId: String
    
    @Field(key: "name")
    var name: String?
    
    @Children(for: \.$slackUser)
    var cob_orders: [CobOrder]
    
    static func newOrExisting(slackId: String, on db: any Database, logger: Logger) async -> SlackUser? {
        do {
            if let existingUser =  try await SlackUser.query(on: db).filter(\.$slackId == slackId).first() {
                return existingUser
            } else {
                let newUser = SlackUser(slackId: slackId)
                try await newUser.save(on: db)
                return newUser
            }
        } catch {
            logger.warning("Unable to register user: \(error)")
            return nil
        }
    }
}
