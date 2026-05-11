//
//  SwitchOutcome.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-11.
//  Co-author: Claude Code
//

/// Where the switch was initiated from.
/// Determines whether missing shortcuts show a balloon (click) or
/// cause the target to be unreachable/greyed out (menu).
enum SwitchEntryPoint {
    case click
    case menu
}

/// The resolved action for switching to a space.
enum SwitchOutcome: Equatable {

    // Shortcut-based (executed by ShortcutSwitcher)

    /// Direct keyboard shortcut (AppleScript keypress).
    case shortcutDirect(switchIndex: Int)

    /// One arrow keypress left/right.
    case shortcutRelative(goRight: Bool)

    /// Chain arrow keypresses from the current position.
    case shortcutChain(steps: Int, goRight: Bool)

    /// Jump to an anchor space, then chain remaining arrows.
    case shortcutJumpThenChain(
        anchorSwitchIndex: Int, steps: Int, goRight: Bool)

    // Gesture-based (executed by GestureSwitcher)

    /// Gesture-based switch to a specific space on the same display.
    case gestureDirect(
        target: Space, current: Space, mode: SwitchingMode)

    /// Gesture one step left/right.
    case gestureRelative(goRight: Bool, mode: SwitchingMode)

    // Non-switching

    /// Trigger Mission Control.
    case missionControl

    /// Show the "configure shortcuts" balloon.
    case showBalloon(MissingShortcutKind)

    /// Target cannot be reached.
    case unreachable
}
