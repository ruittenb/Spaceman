//
//  SpaceSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-08-28.
//

import Foundation
import SwiftUI

enum MissingShortcutKind {
    case navigation  // Mission Control, Move left/right
    case desktop     // Switch to Desktop N
}

class SpaceSwitcher {
    let shortcutSwitcher = ShortcutSwitcher()
    private let gestureSwitcher = GestureSwitcher()
    @AppStorage("switchingMode") private var switchingMode = SwitchingMode.smooth.rawValue

    // MARK: - Strategizer (static, pure)

    /// Determine the switch outcome for a space target.
    static func resolveOutcome(
        switchTag: Int,
        entryPoint: SwitchEntryPoint,
        mode: SwitchingMode,
        spaces: [Space],
        enabledSwitchMap: [String: Int],
        hasArrowShortcuts: Bool
    ) -> SwitchOutcome {
        // Resolve target and current space
        let targetSpaceNumber: Int
        let target: Space?
        if switchTag > 0 {
            // Positive tag = switch index → find space by switch map
            let switchMap = Space.buildSwitchIndexMap(for: spaces)
            target = spaces.first { switchMap[$0.spaceID] == switchTag }
            targetSpaceNumber = target?.spaceNumber ?? 0
        } else {
            // Negative tag = -(spaceNumber)
            targetSpaceNumber = -switchTag
            target = spaces.first { $0.spaceNumber == targetSpaceNumber }
        }
        guard let target,
              let current = spaces.first(where: { $0.isCurrentSpace })
        else {
            return .unreachable
        }

        let sameDisplay = target.displayID == current.displayID

        // Gesture mode, same display → gesture
        if mode != .smooth && sameDisplay {
            return .gestureDirect(
                target: target, current: current, mode: mode)
        }
        // Gesture mode, cross display → fall through to shortcut logic

        // Does the target have an enabled direct shortcut?
        let enabledIndex = enabledSwitchMap.first(
            where: { $0.key == target.spaceID })?.value
        if let enabledIndex,
           enabledIndex >= 1, enabledIndex <= Space.maxSwitchableDesktop {
            return .shortcutDirect(switchIndex: enabledIndex)
        }

        // Desktop without shortcut + click → show balloon
        if !target.isFullScreen && switchTag > 0
            && entryPoint == .click {
            return .showBalloon(.desktop)
        }

        // Try chaining
        let strategy = calculateChainingStrategy(
            targetSpaceNumber: targetSpaceNumber, spaces: spaces,
            switchMap: enabledSwitchMap,
            hasArrowShortcuts: hasArrowShortcuts)

        switch strategy {
        case .chainFromCurrent(let steps, let goRight):
            return .shortcutChain(steps: steps, goRight: goRight)
        case .jumpThenChain(let anchorIndex, let steps, let goRight):
            return .shortcutJumpThenChain(
                anchorSwitchIndex: anchorIndex,
                steps: steps, goRight: goRight)
        case .directSwitch(let switchIndex):
            return .shortcutDirect(switchIndex: switchIndex)
        case .unreachable:
            if entryPoint == .click {
                return .showBalloon(
                    target.isFullScreen ? .navigation : .desktop)
            }
            return .unreachable
        }
    }

    /// Determine the outcome for navigation buttons (prev/next, Mission Control).
    static func resolveNavigationOutcome(
        hitIndex: Int,
        mode: SwitchingMode,
        spaces: [Space],
        hasArrowShortcuts: Bool,
        entryPoint: SwitchEntryPoint
    ) -> SwitchOutcome {
        if hitIndex == Space.missionControlIndex {
            return .missionControl
        }

        let goRight = hitIndex == Space.nextSpaceIndex

        if isAtEdge(spaces: spaces, goingRight: goRight) {
            return .unreachable
        }

        if mode != .smooth {
            return .gestureRelative(goRight: goRight, mode: mode)
        }

        // Smooth mode: need arrow shortcuts
        let hasShortcut = goRight
            ? hasArrowShortcuts
            : hasArrowShortcuts
        if !hasShortcut {
            return entryPoint == .click
                ? .showBalloon(.navigation)
                : .unreachable
        }
        return .shortcutRelative(goRight: goRight)
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

    // MARK: - Executor (instance)

    /// Execute a resolved switch outcome.
    func executeOutcome(
        _ outcome: SwitchOutcome,
        spaces: [Space],
        onError: @escaping () -> Void,
        onShowBalloon: ((MissingShortcutKind) -> Void)? = nil
    ) {
        switch outcome {
        case .shortcutDirect(let switchIndex):
            shortcutSwitcher.switchToSpace(
                switchIndex, onError: onError)

        case .shortcutRelative(let goRight):
            shortcutSwitcher.switchRelative(goRight: goRight)

        case .shortcutChain(let steps, let goRight):
            shortcutSwitcher.chain(
                steps: steps, goRight: goRight, onError: onError)

        case .shortcutJumpThenChain(
            let anchorIndex, let steps, let goRight
        ):
            shortcutSwitcher.jumpThenChain(
                anchor: anchorIndex, steps: steps,
                goRight: goRight, onError: onError)

        case .gestureDirect(let target, let current, let mode):
            _ = gestureSwitcher.switchToSpace(
                target: target, current: current,
                spaces: spaces, mode: mode)

        case .gestureRelative(let goRight, let mode):
            gestureSwitcher.switchRelative(
                goRight: goRight, mode: mode)

        case .missionControl:
            shortcutSwitcher.triggerMissionControl()

        case .showBalloon(let kind):
            if let onShowBalloon {
                onShowBalloon(kind)
            } else {
                onError()
            }

        case .unreachable:
            onError()
        }
    }

    // MARK: - Entry point (click on icon)

    public func switchUsingLocation(
        iconWidths: [IconWidth], point: CGPoint,
        spaces: [Space],
        onError: @escaping () -> Void,
        onShowBalloon: ((MissingShortcutKind) -> Void)? = nil
    ) {
        shortcutSwitcher.reloadShortcuts()
        shortcutSwitcher.cancelChain()

        // Hit-test
        var hitIndex: Int?
        var hitSpaceNumber: Int = 0
        for i in 0 ..< iconWidths.count {
            let hitX = point.x >= iconWidths[i].left
                && point.x < iconWidths[i].right
            let hasY = iconWidths[i].top != 0
                || iconWidths[i].bottom != 0
            let hitY = hasY
                ? (point.y >= iconWidths[i].top
                    && point.y < iconWidths[i].bottom)
                : true
            if hitX && hitY {
                hitIndex = iconWidths[i].index
                hitSpaceNumber = iconWidths[i].spaceNumber
                break
            }
        }
        guard let hitIndex else {
            onError()
            return
        }

        let mode = SwitchingMode(rawValue: switchingMode) ?? .smooth
        let enabledMap = shortcutSwitcher.buildEnabledSwitchMap(
            for: spaces)

        // Navigation buttons (prev/next/Mission Control)
        if hitIndex == Space.missionControlIndex
            || hitIndex == Space.previousSpaceIndex
            || hitIndex == Space.nextSpaceIndex {
            let outcome = Self.resolveNavigationOutcome(
                hitIndex: hitIndex, mode: mode,
                spaces: spaces,
                hasArrowShortcuts: shortcutSwitcher.hasArrowShortcuts,
                entryPoint: .click)
            executeOutcome(
                outcome, spaces: spaces,
                onError: onError, onShowBalloon: onShowBalloon)
            return
        }

        // Regular space
        let tag = Space.switchTag(
            switchMapEntry: Space.buildSwitchIndexMap(
                for: spaces)[spaces.first(
                    where: { $0.spaceNumber == hitSpaceNumber }
                )?.spaceID ?? ""],
            spaceNumber: hitSpaceNumber)
        let outcome = Self.resolveOutcome(
            switchTag: tag, entryPoint: .click, mode: mode,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: shortcutSwitcher.hasArrowShortcuts)
        executeOutcome(
            outcome, spaces: spaces,
            onError: onError, onShowBalloon: onShowBalloon)
    }

    // MARK: - Chaining strategy (static building blocks)

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
            guard let idx = switchMap[$0.spaceID] else { return false }
            return idx >= 1 && idx <= Space.maxSwitchableDesktop
        }
        let goingRight = targetSpaceNumber > currentSpaceNumber
        return switchable.min(by: {
            let d0 = abs($0.spaceNumber - targetSpaceNumber)
            let d1 = abs($1.spaceNumber - targetSpaceNumber)
            if d0 != d1 { return d0 < d1 }
            if goingRight { return $0.spaceNumber < $1.spaceNumber }
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
        hasArrowShortcuts: Bool = true
    ) -> ChainingStrategy {
        guard let targetSpace = spaces.first(
            where: { $0.spaceNumber == targetSpaceNumber }),
              let currentSpace = spaces.first(
                where: { $0.isCurrentSpace })
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
        let sameDisplay =
            targetSpace.displayID == currentSpace.displayID
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
