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
    case manualRefresh   // User changed a setting or triggered refresh (ButtonPressed)
    case autoRefresh     // Periodic auto-refresh timer (RefreshSpaces)
}
