//
//  IconSize.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-09-27.
//

import Foundation

enum IconSize: Int, CaseIterable {
    case narrow = 0
    case compact = 1
    case medium = 2
    case large = 3
    case extraLarge = 4
    case enormous = 5

    /// The next larger size, or nil if already at the largest.
    var larger: IconSize? {
        IconSize(rawValue: rawValue + 1)
    }

    /// The next smaller size, or nil if already at the smallest.
    var smaller: IconSize? {
        IconSize(rawValue: rawValue - 1)
    }

    var menuLabel: String {
        switch self {
        case .narrow:     return String(localized: "Narrow")
        case .compact:    return String(localized: "Compact")
        case .medium:     return String(localized: "Medium")
        case .large:      return String(localized: "Large")
        case .extraLarge: return String(localized: "Extra Large")
        case .enormous:   return String(localized: "Enormous")
        }
    }
}
