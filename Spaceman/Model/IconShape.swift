//
//  IconShape.swift
//  Spaceman
//
//  Created by Claude Code on 30/03/2026.
//

import Foundation

enum IconShape: Int, CaseIterable {
    case noDecoration = 0
    case rectangular = 1
    case rounded = 2
    case pill = 3

    var menuLabel: String {
        switch self {
        case .noDecoration: return String(localized: "No Decoration")
        case .rectangular:  return String(localized: "Rectangular")
        case .rounded:      return String(localized: "Rounded")
        case .pill:         return String(localized: "Pill")
        }
    }
}
