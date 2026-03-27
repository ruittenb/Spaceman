//
//  LayoutMode.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 27/09/2024.
//

import Foundation

enum LayoutMode: Int, CaseIterable {
    case dualRows = 0
    case narrow = 5
    case compact = 1
    case medium = 2
    case large = 3
    case extraLarge = 4

    var menuLabel: String {
        switch self {
        case .dualRows:   return String(localized: "Dual Row")
        case .narrow:     return String(localized: "Narrow")
        case .compact:    return String(localized: "Compact")
        case .medium:     return String(localized: "Medium")
        case .large:      return String(localized: "Large")
        case .extraLarge: return String(localized: "Extra Large")
        }
    }
}
