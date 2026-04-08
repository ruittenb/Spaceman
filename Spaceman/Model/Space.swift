//
//  Space.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Foundation

struct Space: Equatable {
    var displayID: String        // OS display UUID
    var spaceID: String          // OS space ID
    var spaceName: String        // space name, user assigned
    var spaceNumber: Int         // space number, sequential, not restarted
    var spaceByDesktopID: String // space number as shown (possibly restarted)
    var isCurrentSpace: Bool
    var isFullScreen: Bool
    var colorHex: String?        // Custom color tint (hex string)

    /// Maximum number of desktops that macOS supports keyboard shortcuts for (IDs 118–133).
    static let maxSwitchableDesktop = 16

    // Special switch indices. Desktops use 1–maxSwitchableDesktop.
    // These are deliberately far below that range to avoid collisions.

    /// Switch index used when a space has no keyboard shortcut.
    static let unswitchableIndex = -99

    /// Switch index for the Mission Control button.
    static let missionControlIndex = -100

    /// Switch index for the previous-space arrow (Ctrl+Left).
    static let previousSpaceIndex = -101

    /// Switch index for the next-space arrow (Ctrl+Right).
    static let nextSpaceIndex = -102

    /// Build a mapping from spaceID to Mission Control switch index.
    /// Regular desktops get 1, 2, ... up to `maxSwitchableDesktop` (matching
    /// keyboard shortcuts read from macOS user defaults). Beyond that, omitted.
    ///
    /// Fullscreen spaces are omitted from the map so they get
    /// `unswitchableIndex` and are handled by chaining or error flash.
    static func buildSwitchIndexMap(for spaces: [Space]) -> [String: Int] {
        var map: [String: Int] = [:]
        var desktopIndex = 1
        for s in spaces where !s.isFullScreen {
            if desktopIndex <= maxSwitchableDesktop {
                map[s.spaceID] = desktopIndex
            }
            desktopIndex += 1
        }
        return map
    }
}
