//
//  IconFill.swift
//  Spaceman
//

import Foundation

enum IconFill: Int, CaseIterable {
    case bordered = 0
    case filled = 1

    var menuLabel: String {
        switch self {
        case .bordered: return String(localized: "Bordered")
        case .filled:   return String(localized: "Filled")
        }
    }
}
