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
    var displayUUID: String? = nil      // Physical display identifier
    var positionOnDisplay: Int? = nil   // Position on this display (1,2,3...)

    // For current UI display:
    var currentDisplayIndex: Int? = nil // Logical display number (1,2,3)
    var currentSpaceNumber: Int? = nil  // Number shown in UI
}
