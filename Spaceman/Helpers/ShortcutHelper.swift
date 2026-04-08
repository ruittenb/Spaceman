//
//  ShortcutHelper.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-08-28.
//
//  Reads Mission Control keyboard shortcuts from macOS user defaults
//  (com.apple.symbolichotkeys) so Spaceman sends the correct keypresses.

import Foundation
import SwiftUI

/// A resolved keyboard shortcut: keycode + AppleScript modifier string + NSEvent modifier flags.
struct SpaceShortcut {
    let keyCode: Int
    let modifiers: String          // AppleScript format: "control down,command down"
    let modifierFlags: NSEvent.ModifierFlags
    let keyEquivalent: String      // For NSMenuItem display: "1", "2", etc.
}

class ShortcutHelper {

    // Plist hotkey IDs for "Switch to Desktop N"
    // 118-127 = Desktop 1-10, 128-132 = Desktop 11-15
    private static let desktopHotkeyBaseID = 118

    // Navigation hotkey IDs
    private static let moveLeftID = 79
    private static let moveRightID = 81
    private static let missionControlID = 32

    /// Cached shortcuts, keyed by desktop number (1-15).
    private var desktopShortcuts: [Int: SpaceShortcut] = [:]

    /// Cached navigation shortcuts.
    private(set) var moveLeftShortcut: SpaceShortcut?
    private(set) var moveRightShortcut: SpaceShortcut?
    private(set) var missionControlShortcut: SpaceShortcut?

    /// Synthesized shortcut for the first fullscreen space (minus key + Desktop 1's modifiers).
    private(set) var fullscreenShortcut: SpaceShortcut?

    init() {
        reload()
    }

    /// Re-read shortcuts from macOS user defaults.
    func reload() {
        desktopShortcuts.removeAll()
        guard let plist = UserDefaults(suiteName: "com.apple.symbolichotkeys"),
              let hotkeys = plist.persistentDomain(
                forName: "com.apple.symbolichotkeys"
              )?["AppleSymbolicHotKeys"] as? [String: Any] else {
            return
        }

        // Desktop shortcuts (1-15)
        for desktop in 1...Space.maxSwitchableDesktop {
            let hotkeyID = ShortcutHelper.desktopHotkeyBaseID + desktop - 1
            if let shortcut = parseHotkey(id: hotkeyID, from: hotkeys) {
                desktopShortcuts[desktop] = shortcut
            }
        }

        // Navigation shortcuts
        moveLeftShortcut = parseHotkey(id: ShortcutHelper.moveLeftID, from: hotkeys)
        moveRightShortcut = parseHotkey(id: ShortcutHelper.moveRightID, from: hotkeys)
        missionControlShortcut = parseHotkey(id: ShortcutHelper.missionControlID, from: hotkeys)

        // Hardcoded F1 fullscreen shortcut: ⌃⌘- (marginally supported, for Apptivate etc.)
        fullscreenShortcut = SpaceShortcut(
            keyCode: 27,  // VK_ANSI_Minus
            modifiers: "control down,command down",
            modifierFlags: [.control, .command],
            keyEquivalent: "-"
        )
    }

    /// Returns the shortcut for a given desktop number (1-15), or nil if not configured/enabled.
    func shortcut(forDesktop desktop: Int) -> SpaceShortcut? {
        return desktopShortcuts[desktop]
    }

    // MARK: - SpaceSwitcher support

    /// Returns the keycode for a desktop number, or -1 if unavailable.
    func getKeyCode(spaceNumber: Int) -> Int {
        return desktopShortcuts[spaceNumber]?.keyCode ?? -1
    }

    /// Returns the AppleScript modifier string for a desktop number.
    func getModifiers(spaceNumber: Int) -> String {
        return desktopShortcuts[spaceNumber]?.modifiers ?? ""
    }

    // MARK: - Plist parsing

    private func parseHotkey(id: Int, from hotkeys: [String: Any]) -> SpaceShortcut? {
        guard let entry = hotkeys[String(id)] as? [String: Any],
              let enabled = entry["enabled"] as? Bool, enabled,
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int],
              params.count >= 3 else {
            return nil
        }

        let keyCode = params[1]
        let modRaw = params[2]

        // Build AppleScript modifier string
        var mods: [String] = []
        if modRaw & (1 << 17) != 0 { mods.append("shift down") }
        if modRaw & (1 << 18) != 0 { mods.append("control down") }
        if modRaw & (1 << 19) != 0 { mods.append("option down") }
        if modRaw & (1 << 20) != 0 { mods.append("command down") }

        // Build NSEvent modifier flags
        var flags = NSEvent.ModifierFlags()
        if modRaw & (1 << 17) != 0 { flags.insert(.shift) }
        if modRaw & (1 << 18) != 0 { flags.insert(.control) }
        if modRaw & (1 << 19) != 0 { flags.insert(.option) }
        if modRaw & (1 << 20) != 0 { flags.insert(.command) }

        // Key equivalent character for menu display
        let keyEquivalent = keyCodeToCharacter(keyCode)

        return SpaceShortcut(
            keyCode: keyCode,
            modifiers: mods.joined(separator: ","),
            modifierFlags: flags,
            keyEquivalent: keyEquivalent
        )
    }

    /// Map a virtual keycode to a display character for NSMenuItem.keyEquivalent.
    private func keyCodeToCharacter(_ keyCode: Int) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 83: return "1"  // Keypad
        case 84: return "2"
        case 85: return "3"
        case 86: return "4"
        case 87: return "5"
        case 88: return "6"
        case 89: return "7"
        case 91: return "8"
        case 92: return "9"
        case 82: return "0"
        default: return ""
        }
    }
}
