//
//  SpaceNameInfo.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 6/12/20.
//

import Foundation

struct SpaceNameInfo: Hashable, Codable {
    let spaceNum: Int
    let spaceName: String
    let spaceByDesktopID: String

    // For resilience against ManagedSpaceID changes:
    var displayUUID: String?      // Physical display identifier
    var positionOnDisplay: Int?   // Position on this display (1,2,3...)

    // For current UI display:
    var currentDisplayIndex: Int? // Logical display number (1,2,3)
    var currentSpaceNumber: Int?  // Number shown in UI

    // Custom color tinting (hex string, e.g., "FF5733")
    var colorHex: String?

    /// Whether this entry has user-assigned data worth preserving (custom name or color).
    var hasUserData: Bool {
        return !spaceName.isEmpty || colorHex != nil
    }
}
