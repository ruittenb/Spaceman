//
//  IconFill.swift
//  Spaceman
//
//  Created by Claude Code on 30/03/2026.
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
