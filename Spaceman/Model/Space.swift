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
    /// Fullscreen spaces are not in the map (no macOS shortcut exists for them).
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

    /// Whether a space can be switched to, given its switch map tag.
    /// Used by both grid and list views to determine if a space is clickable.
    static func canSwitch(
        space: Space, switchTag: Int?,
        switchingMode: SwitchingMode = .smooth,
        spaces: [Space] = []
    ) -> Bool {
        guard !space.isCurrentSpace else { return false }
        if switchingMode != .smooth { return true }
        // Has a direct shortcut (desktop 1-16)
        if switchTag != nil { return true }
        // Fullscreen: reachable only if chaining can reach it
        if space.isFullScreen {
            let strategy = SpaceSwitcher.calculateChainingStrategy(
                targetSpaceNumber: space.spaceNumber, spaces: spaces)
            return strategy != .unreachable
        }
        return false
    }

    /// The tag to pass to the switch handler for this space.
    /// Positive for regular desktops, negative (-(spaceNumber)) for fullscreen/unswitchable.
    static func switchTag(switchMapEntry: Int?, spaceNumber: Int) -> Int {
        if let tag = switchMapEntry, tag > 0 { return tag }
        return -(spaceNumber)
    }
}
