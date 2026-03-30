//
//  IconFill.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-03-30.
//  Co-author: Claude Code
//

import Foundation

enum IconFill: Int, CaseIterable {
    case bordered = 0
    case filled = 1
    case filledBordered = 2

    var menuLabel: String {
        switch self {
        case .bordered:       return String(localized: "Bordered")
        case .filled:         return String(localized: "Filled")
        case .filledBordered: return String(localized: "Filled Bordered")
        }
    }
}
