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

    /// Switch index used when a space has no keyboard shortcut (e.g. beyond desktop 10).
    /// Any negative index causes SpaceSwitcher to trigger onError instead of switching.
    static let unswitchableIndex = -99

    /// Build a mapping from spaceID to Mission Control switch index.
    /// Regular desktops get 1, 2, ... up to 10 (matching ⌃1–⌃0 shortcuts).
    /// Fullscreen spaces get -1, -2, -3, .... Desktops beyond 10 are omitted.
    static func buildSwitchIndexMap(for spaces: [Space]) -> [String: Int] {
        var map: [String: Int] = [:]
        var desktopIndex = 1
        var fullscreenIndex = 1
        for s in spaces {
            if s.isFullScreen {
                map[s.spaceID] = -fullscreenIndex
                fullscreenIndex += 1
            } else {
                if desktopIndex <= 10 {
                    map[s.spaceID] = desktopIndex
                }
                desktopIndex += 1
            }
        }
        return map
    }
}
