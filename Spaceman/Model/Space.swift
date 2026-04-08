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
    /// The first fullscreen space (F1) is mapped to -1 so it can be
    /// distinguished for the hidden minus-key shortcut (used by Apptivate etc.).
    /// Additional fullscreen spaces are omitted and get `unswitchableIndex`.
    static func buildSwitchIndexMap(for spaces: [Space]) -> [String: Int] {
        var map: [String: Int] = [:]
        var desktopIndex = 1
        var fullscreenIndex = 1
        for s in spaces {
            if s.isFullScreen {
                if fullscreenIndex == 1 {
                    map[s.spaceID] = -1
                }
                fullscreenIndex += 1
            } else {
                if desktopIndex <= maxSwitchableDesktop {
                    map[s.spaceID] = desktopIndex
                }
                desktopIndex += 1
            }
        }
        return map
    }
}
