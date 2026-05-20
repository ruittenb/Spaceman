//
//  SwitchStrategy.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-11.
//  Co-author: Claude Code
//

// Space switching is split into three layers:
//
//   Strategizer → Strategy → Executor
//
// The strategizer (SwitchStrategizer.resolveStrategy) is a pure static
// function that decides *what* to do. It returns a SwitchStrategy.
// The orchestrator (SwitchOrchestrator.executeStrategy) maps each
// strategy to the corresponding ShortcutSwitcher or GestureSwitcher call.
//
// This separation means:
// - The decision logic is testable without AppleScript or CGEvents.
// - Both entry points (icon click and menu click) call the same
//   strategizer, so their behavior can't diverge.
// - Every possible action is an explicit enum case — no hidden
//   paths or implicit behavior from callback presence/absence.

/// Where the switch was initiated from.
/// Determines whether missing shortcuts show a balloon (click) or
/// cause the target to be unreachable/greyed out (menu).
enum SwitchEntryPoint {
    case click
    case menu
}

/// Context shared by the strategizer methods.
struct SwitchContext {
    let entryPoint: SwitchEntryPoint
    let mode: SwitchingMode
    let spaces: [Space]
    let enabledSwitchMap: [String: Int]
    let hasArrowShortcuts: Bool

    /// The display UUID where the user has focus (from
    /// NSScreen.main). Gestures only affect this display.
    /// When nil, the strategizer falls back to array order.
    let focusedDisplayID: String?

    init(
        entryPoint: SwitchEntryPoint,
        mode: SwitchingMode,
        spaces: [Space],
        enabledSwitchMap: [String: Int],
        hasArrowShortcuts: Bool,
        focusedDisplayID: String? = nil
    ) {
        self.entryPoint = entryPoint
        self.mode = mode
        self.spaces = spaces
        self.enabledSwitchMap = enabledSwitchMap
        self.hasArrowShortcuts = hasArrowShortcuts
        self.focusedDisplayID = focusedDisplayID
    }
}

/// The resolved action for switching to a space.
/// Cases are prefixed by their executor: `shortcut*` maps to
/// ShortcutSwitcher, `gesture*` maps to GestureSwitcher.
enum SwitchStrategy: Equatable {

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

    /// Gesture jump to anchor (instant), then chain arrows via shortcuts.
    case gestureJumpThenChain(
        anchor: Space, current: Space,
        steps: Int, goRight: Bool)

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
