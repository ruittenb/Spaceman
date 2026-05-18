//
//  SwitchStrategizer.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-11.
//  Co-author: Claude Code
//
//  Pure decision logic: given a target space and context, returns
//  a SwitchStrategy describing what action to take. No side effects,
//  no UI, no AppleScript — fully unit-testable.

import Foundation

enum MissingShortcutKind {
    case navigation  // Mission Control, Move left/right
    case desktop     // Switch to Desktop N
}

enum SwitchStrategizer {

    /// Determine the switch strategy for a space target.
    static func resolveStrategy(
        switchTag: Int, context: SwitchContext
    ) -> SwitchStrategy {
        // Resolve target and current space
        let targetSpaceNumber: Int
        let target: Space?
        if switchTag > 0 {
            let switchMap = Space.buildSwitchIndexMap(
                for: context.spaces)
            target = context.spaces.first {
                switchMap[$0.spaceID] == switchTag
            }
            targetSpaceNumber = target?.spaceNumber ?? 0
        } else {
            targetSpaceNumber = -switchTag
            target = context.spaces.first {
                $0.spaceNumber == targetSpaceNumber
            }
        }
        guard let target,
              let current = findCurrentSpace(
                in: context.spaces,
                preferringDisplayOf: target)
        else {
            return .unreachable
        }

        // Gestures only affect the focused display. Use
        // focusedDisplayID (from NSScreen.main) when available;
        // fall back to the first current space in the array
        // (typically the primary display from CGS).
        // findCurrentSpace(preferringDisplayOf:) can't be used
        // here — it always returns a space on the target's
        // display, making sameDisplay unconditionally true.
        let sameDisplay: Bool
        if let focusedID = context.focusedDisplayID {
            sameDisplay = target.displayID == focusedID
        } else {
            let focused = context.spaces.first(
                where: { $0.isCurrentSpace })
            sameDisplay = target.displayID
                == focused?.displayID
        }

        // Gesture mode, same display → gesture
        if context.mode != .smooth && sameDisplay {
            return .gestureDirect(
                target: target, current: current,
                mode: context.mode)
        }
        // Gesture mode, cross display → fall through to shortcut logic

        // Does the target have an enabled direct shortcut?
        let enabledIndex = context.enabledSwitchMap[target.spaceID]
        if let enabledIndex,
           enabledIndex >= 1,
           enabledIndex <= Space.maxSwitchableDesktop {
            return .shortcutDirect(switchIndex: enabledIndex)
        }

        // Desktop without shortcut + click → show balloon.
        // Desktops *could* have a shortcut (unlike fullscreen), so we
        // nudge the user to enable it rather than silently chaining.
        // Menu items skip this and try chaining instead (greyed out
        // if unreachable) — the balloon would be disruptive in a menu.
        if !target.isFullScreen && switchTag > 0
            && context.entryPoint == .click {
            return .showBalloon(.desktop)
        }

        // Try chaining
        let chaining = calculateChainingStrategy(
            targetSpaceNumber: targetSpaceNumber,
            spaces: context.spaces,
            switchMap: context.enabledSwitchMap,
            hasArrowShortcuts: context.hasArrowShortcuts,
            focusedDisplayID: context.focusedDisplayID)

        switch chaining {
        case .chainFromCurrent(let steps, let goRight):
            return .shortcutChain(steps: steps, goRight: goRight)
        case .jumpThenChain(
            let anchorIndex, let steps, let goRight
        ):
            if sameDisplay,
               let anchor = context.spaces.first(where: {
                   context.enabledSwitchMap[$0.spaceID]
                       == anchorIndex
               }) {
                return .gestureJumpThenChain(
                    anchor: anchor, current: current,
                    steps: steps, goRight: goRight)
            }
            return .shortcutJumpThenChain(
                anchorSwitchIndex: anchorIndex,
                steps: steps, goRight: goRight)
        case .directSwitch(let switchIndex):
            return .shortcutDirect(switchIndex: switchIndex)
        case .unreachable:
            if context.entryPoint == .click {
                return .showBalloon(
                    target.isFullScreen ? .navigation : .desktop)
            }
            return .unreachable
        }
    }

    /// Determine the strategy for navigation buttons
    /// (prev/next, Mission Control).
    static func resolveNavigationStrategy(
        hitIndex: Int, context: SwitchContext
    ) -> SwitchStrategy {
        if hitIndex == Space.missionControlIndex {
            return .missionControl
        }

        let goRight = hitIndex == Space.nextSpaceIndex

        if isAtEdge(
            spaces: context.spaces, goingRight: goRight) {
            return .unreachable
        }

        if context.mode != .smooth {
            return .gestureRelative(
                goRight: goRight, mode: context.mode)
        }

        if !context.hasArrowShortcuts {
            return context.entryPoint == .click
                ? .showBalloon(.navigation)
                : .unreachable
        }
        return .shortcutRelative(goRight: goRight)
    }

    // MARK: - Building blocks

    /// Find the current space, preferring the one on the same
    /// display as `target`. In a multi-display setup each display
    /// has its own current space; picking the wrong one makes a
    /// same-display switch look cross-display.
    private static func findCurrentSpace(
        in spaces: [Space], preferringDisplayOf target: Space
    ) -> Space? {
        spaces.first(where: {
            $0.isCurrentSpace && $0.displayID == target.displayID
        }) ?? spaces.first(where: { $0.isCurrentSpace })
    }

    /// Returns true when the current space is already at the
    /// first (goingRight=false) or last (goingRight=true)
    /// position on its display.
    static func isAtEdge(
        spaces: [Space], goingRight: Bool
    ) -> Bool {
        guard let current = spaces.first(
            where: { $0.isCurrentSpace })
        else {
            return false
        }
        let displaySpaces = spaces
            .filter { $0.displayID == current.displayID }
            .sorted { $0.spaceNumber < $1.spaceNumber }
        if goingRight {
            return current.spaceNumber
                == displaySpaces.last?.spaceNumber
        } else {
            return current.spaceNumber
                == displaySpaces.first?.spaceNumber
        }
    }

    /// Find the nearest desktop with an enabled shortcut on the same
    /// display as the target space. When two anchors are equally close
    /// to the target, prefer the one between current and target
    /// (i.e. "along the way").
    static func findNearestAnchor(
        targetSpaceNumber: Int, currentSpaceNumber: Int,
        spaces: [Space], switchMap: [String: Int]
    ) -> Space? {
        guard let targetSpace = spaces.first(
            where: { $0.spaceNumber == targetSpaceNumber })
        else { return nil }
        let targetDisplaySpaces = spaces.filter {
            $0.displayID == targetSpace.displayID
        }
        let switchable = targetDisplaySpaces.filter {
            guard let idx = switchMap[$0.spaceID]
            else { return false }
            return idx >= 1 && idx <= Space.maxSwitchableDesktop
        }
        let goingRight = targetSpaceNumber > currentSpaceNumber
        return switchable.min(by: {
            let d0 = abs($0.spaceNumber - targetSpaceNumber)
            let d1 = abs($1.spaceNumber - targetSpaceNumber)
            if d0 != d1 { return d0 < d1 }
            if goingRight {
                return $0.spaceNumber < $1.spaceNumber
            }
            return $0.spaceNumber > $1.spaceNumber
        })
    }

    /// Calculate the optimal chaining strategy without executing it.
    /// When `hasArrowShortcuts` is false, strategies that require
    /// chaining (arrow keypresses) are excluded — only `directSwitch`
    /// survives.
    static func calculateChainingStrategy(
        targetSpaceNumber: Int, spaces: [Space],
        switchMap: [String: Int]? = nil,
        hasArrowShortcuts: Bool = true,
        focusedDisplayID: String? = nil
    ) -> ChainingStrategy {
        guard let targetSpace = spaces.first(
            where: { $0.spaceNumber == targetSpaceNumber }),
              let currentSpace = findCurrentSpace(
                in: spaces,
                preferringDisplayOf: targetSpace)
        else {
            return .unreachable
        }

        let switchMap = switchMap
            ?? Space.buildSwitchIndexMap(for: spaces)
        let anchor = findNearestAnchor(
            targetSpaceNumber: targetSpaceNumber,
            currentSpaceNumber: currentSpace.spaceNumber,
            spaces: spaces, switchMap: switchMap)

        let maxArrows = 100
        let arrowsFromAnchor = anchor.map {
            abs(targetSpaceNumber - $0.spaceNumber)
        } ?? maxArrows + 1
        // Arrow keys operate on the focused display.
        // Chain-from-current is only valid if the target is
        // on the same display the user currently has focus on.
        let sameDisplay: Bool
        if let focusedID = focusedDisplayID {
            sameDisplay = targetSpace.displayID == focusedID
        } else {
            sameDisplay = targetSpace.displayID
                == currentSpace.displayID
        }
        let arrowsFromCurrent = sameDisplay
            ? abs(targetSpaceNumber - currentSpace.spaceNumber)
            : maxArrows + 1

        if hasArrowShortcuts
            && arrowsFromCurrent <= maxArrows
            && arrowsFromCurrent <= arrowsFromAnchor + 1 {
            guard arrowsFromCurrent > 0 else {
                return .unreachable
            }
            let goRight =
                targetSpaceNumber > currentSpace.spaceNumber
            return .chainFromCurrent(
                steps: arrowsFromCurrent, goRight: goRight)
        } else if let anchor = anchor,
                  let switchIndex = switchMap[anchor.spaceID] {
            let delta = targetSpaceNumber - anchor.spaceNumber
            if delta == 0 {
                return .directSwitch(switchIndex: switchIndex)
            }
            guard hasArrowShortcuts else { return .unreachable }
            return .jumpThenChain(
                anchorSwitchIndex: switchIndex,
                steps: abs(delta), goRight: delta > 0)
        } else {
            return .unreachable
        }
    }
}
