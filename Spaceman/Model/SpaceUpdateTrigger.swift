//
//  SpaceUpdateTrigger.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-22.
//

import Foundation

/// What caused a space information update. The app delegate uses this to
/// decide whether to retry the user's chosen icon size (fit-to-width).
enum SpaceUpdateTrigger {
    case spaceSwitch     // User switched spaces (activeSpaceDidChangeNotification)
    case topologyChange  // Display connected/disconnected/mirrored (didChangeScreenParametersNotification)
    case userRefresh     // User changed a setting or triggered refresh (SettingsChanged)
    case autoRefresh     // Periodic auto-refresh timer (AutoRefreshTriggered)
    case sessionActive   // Screen unlock or user session resumed (sessionDidBecomeActiveNotification)

    /// Whether this trigger should discard the fitted icon size and retry the
    /// user's chosen size. Space switches deliberately keep the fitted size so
    /// the icon does not blink on every switch.
    var resetsFittedSize: Bool {
        switch self {
        case .topologyChange, .userRefresh, .sessionActive:
            return true
        case .spaceSwitch, .autoRefresh:
            return false
        }
    }
}
