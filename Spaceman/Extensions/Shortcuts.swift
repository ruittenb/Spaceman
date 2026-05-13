//
//  Shortcuts.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-13.
//  Co-author: Claude Code
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let refresh = Self(
        "refresh",
        default: .init(.r, modifiers: [.control, .option, .command]))
    static let preferences = Self(
        "preferences",
        default: .init(.p, modifiers: [.control, .option, .command]))
    static let quickRename = Self(
        "quickRename",
        default: .init(.n, modifiers: [.control, .option, .command]))
}
