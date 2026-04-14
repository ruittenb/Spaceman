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

    /// Return a copy with only the space name changed.
    func withName(_ newName: String) -> SpaceNameInfo {
        var copy = SpaceNameInfo(spaceNum: spaceNum, spaceName: newName, spaceByDesktopID: spaceByDesktopID)
        copy.displayUUID = displayUUID
        copy.positionOnDisplay = positionOnDisplay
        copy.currentDisplayIndex = currentDisplayIndex
        copy.currentSpaceNumber = currentSpaceNumber
        copy.colorHex = colorHex
        return copy
    }

    /// Return a copy with only the color changed.
    func withColor(_ newColorHex: String?) -> SpaceNameInfo {
        var copy = SpaceNameInfo(spaceNum: spaceNum, spaceName: spaceName, spaceByDesktopID: spaceByDesktopID)
        copy.displayUUID = displayUUID
        copy.positionOnDisplay = positionOnDisplay
        copy.currentDisplayIndex = currentDisplayIndex
        copy.currentSpaceNumber = currentSpaceNumber
        copy.colorHex = newColorHex
        return copy
    }
}
