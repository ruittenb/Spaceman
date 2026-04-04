//
//  NavigationMode.swift
//  Spaceman
//
//  Created by Claude Code on 04/04/2026.
//  Controls which navigation buttons are shown in the status bar.
//

import Foundation

enum NavigationMode: Int, CaseIterable {
    case none = 0
    case missionControl = 1
    case missionControlWithArrows = 2

    var menuLabel: String {
        switch self {
        case .none:                     return String(localized: "None")
        case .missionControl:           return String(localized: "Mission Control")
        case .missionControlWithArrows: return String(localized: "Mission Control + Arrows")
        }
    }
}
