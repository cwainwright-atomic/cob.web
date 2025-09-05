//
//  Enums.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 15/08/2025.
//

import Fluent

enum Filling: String, Codable {
    case bacon, sausage, egg, vegan_sausage
}

enum Bread: String, Codable {
    case white, brown
}

enum Sauce: String, Codable {
    case red, brown
}

enum CobOrderKind : String, Codable {
    case single, recurring
}

enum CobOrderVariant : Codable {
    case single(CobOrder), recurring(RecurringOrder)
    
    var kind: CobOrderKind {
        switch self {
        case .single:
            return .single
        case .recurring:
            return .recurring
        }
    }
}
