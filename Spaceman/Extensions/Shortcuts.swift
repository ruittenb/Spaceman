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
    static let switchUp = Self(
        "switchUp",
        default: .init(.upArrow, modifiers: [.control, .command]))
    static let switchDown = Self(
        "switchDown",
        default: .init(.downArrow, modifiers: [.control, .command]))
    static let switchBack = Self(
        "switchBack",
        default: .init(.delete, modifiers: [.control, .command]))
    static let moveWindowToPreviousSpace = Self(
        "moveWindowToPreviousSpace",
        default: .init(.leftArrow, modifiers: [.control, .option, .command]))
    static let moveWindowToNextSpace = Self(
        "moveWindowToNextSpace",
        default: .init(.rightArrow, modifiers: [.control, .option, .command]))
}
