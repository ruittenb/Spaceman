//
//  ShrinkLevel.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-22.
//

import Foundation

/// Auto-shrink state for the status bar icon.
/// When the icon is too wide for the menu bar, it progressively shrinks.
enum ShrinkLevel {
    case none      // Normal rendering with user's settings
    case shrunken  // Numbers-only, compact size, no fullscreen/arrows/MC
    case icon      // Static Spaceman app icon
}
