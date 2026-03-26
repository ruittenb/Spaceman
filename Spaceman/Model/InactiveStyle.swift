//
//  InactiveStyle.swift
//  Spaceman
//
//  Created by Claude Code on 19/03/2026.
//
//  Controls how inactive spaces are visually distinguished from the active space.
//

import Foundation

enum InactiveStyle: Int, CaseIterable {
    case bordered = 0  // Active = filled box, Inactive = bordered outline
    case dimmed = 1    // Active = filled box, Inactive = filled at reduced opacity

    var menuLabel: String {
        switch self {
        case .bordered: return String(localized: "Bordered")
        case .dimmed:   return String(localized: "Dimmed")
        }
    }
}
