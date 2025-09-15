//
//  File.swift
//  CobWeb
//
//  Created by Christopher Wainwright on 06/09/2025.
//

import Foundation

enum CobOrderVariant {
    case single(CobOrder), recurring(RecurringOrder)
}
