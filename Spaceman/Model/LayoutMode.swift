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
    case enormous = 6

    /// Layout sizes in order from smallest to largest, excluding dualRows.
    static let sizeOrder: [LayoutMode] = [
        .narrow, .compact, .medium, .large, .extraLarge, .enormous
    ]

    /// The next larger single-row layout, or nil if already at the largest.
    var larger: LayoutMode? {
        guard let idx = Self.sizeOrder.firstIndex(of: self),
              idx + 1 < Self.sizeOrder.count else { return nil }
        return Self.sizeOrder[idx + 1]
    }

    /// The next smaller single-row layout, or nil if already at the smallest.
    var smaller: LayoutMode? {
        guard let idx = Self.sizeOrder.firstIndex(of: self),
              idx > 0 else { return nil }
        return Self.sizeOrder[idx - 1]
    }

    var menuLabel: String {
        switch self {
        case .dualRows:   return String(localized: "Dual Row")
        case .narrow:     return String(localized: "Narrow")
        case .compact:    return String(localized: "Compact")
        case .medium:     return String(localized: "Medium")
        case .large:      return String(localized: "Large")
        case .extraLarge: return String(localized: "Extra Large")
        case .enormous:   return String(localized: "Enormous")
        }
    }
}
