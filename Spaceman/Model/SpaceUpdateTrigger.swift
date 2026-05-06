//
//  SpaceUpdateTrigger.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-22.
//

import Foundation

/// Identifies what caused a space information update, so the delegate
/// can decide whether to reset auto-shrink state.
enum SpaceUpdateTrigger {
    case spaceSwitch     // User switched spaces (activeSpaceDidChangeNotification)
    case topologyChange  // Display connected/disconnected/mirrored (didChangeScreenParametersNotification)
    case userRefresh     // User changed a setting or triggered refresh (SettingsChanged)
    case autoRefresh     // Periodic auto-refresh timer (AutoRefreshTriggered)
    case sessionActive   // Screen unlock or user session resumed (sessionDidBecomeActiveNotification)

    /// Whether this trigger should reset the auto-shrink level back to `.none`.
    var resetsAutoShrink: Bool {
        switch self {
        case .spaceSwitch, .topologyChange, .userRefresh, .sessionActive:
            return true
        case .autoRefresh:
            return false
        }
    }
}
