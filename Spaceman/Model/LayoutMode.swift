//
//  LayoutMode.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 27/09/2024.
//

import Foundation

enum LayoutMode: Int, CaseIterable {
    case dualRows = 0
    case compact = 1
    case medium = 2
    case large = 3
    case extraLarge = 4

    var menuLabel: String {
        switch self {
        case .dualRows:   return "Dual Row"
        case .compact:    return "Compact"
        case .medium:     return "Medium"
        case .large:      return "Large"
        case .extraLarge: return "X Large"
        }
    }
}
