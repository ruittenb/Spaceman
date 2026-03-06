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
    /// Desktops beyond 10 are omitted.
    ///
    /// Switching to fullscreen spaces is not a Spaceman feature. As an
    /// exception, the first fullscreen space (F1) is switchable via menu bar
    /// icon click only. It is mapped to index -1 (the minus key). Additional
    /// fullscreen spaces are intentionally omitted from the map so they get
    /// `unswitchableIndex` and trigger an error flash instead.
    static func buildSwitchIndexMap(for spaces: [Space]) -> [String: Int] {
        var map: [String: Int] = [:]
        var desktopIndex = 1
        var fullscreenIndex = 1
        for s in spaces {
            if s.isFullScreen {
                if fullscreenIndex <= 1 {
                    map[s.spaceID] = -fullscreenIndex
                }
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
