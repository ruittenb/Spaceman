//
//  SwitchOrchestrator.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-08-28.
//

import Foundation
import SwiftUI

/// Connects the strategizer to the executors.
/// Calls SwitchStrategizer to decide what to do, then dispatches
/// to ShortcutSwitcher or GestureSwitcher to do it.
class SwitchOrchestrator {
    let shortcutSwitcher = ShortcutSwitcher()
    private let gestureSwitcher = GestureSwitcher()
    @AppStorage("switchingMode") private var switchingMode
        = SwitchingMode.smooth.rawValue

    /// Execute a resolved switch strategy.
    /// Each shortcut* case maps to shortcutSwitcher, each gesture*
    /// case maps to gestureSwitcher — the naming is intentionally
    /// symmetrical so the mapping is obvious.
    func executeStrategy(
        _ strategy: SwitchStrategy,
        spaces: [Space],
        onError: @escaping () -> Void,
        onShowBalloon: ((MissingShortcutKind) -> Void)? = nil
    ) {
        switch strategy {
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

        case .gestureJumpThenChain(
            let anchor, let current, let steps, let goRight
        ):
            _ = gestureSwitcher.switchToSpace(
                target: anchor, current: current,
                spaces: spaces, mode: .instant)
            shortcutSwitcher.waitThenChain(
                steps: steps, goRight: goRight,
                onError: onError)

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

        let ctx = SwitchContext(
            entryPoint: .click,
            mode: SwitchingMode(rawValue: switchingMode)
                ?? .smooth,
            spaces: spaces,
            enabledSwitchMap: shortcutSwitcher
                .buildEnabledSwitchMap(for: spaces),
            hasArrowShortcuts:
                shortcutSwitcher.hasArrowShortcuts)

        // Navigation buttons (prev/next/Mission Control)
        if hitIndex == Space.missionControlIndex
            || hitIndex == Space.previousSpaceIndex
            || hitIndex == Space.nextSpaceIndex {
            let strategy =
                SwitchStrategizer.resolveNavigationStrategy(
                    hitIndex: hitIndex, context: ctx)
            executeStrategy(
                strategy, spaces: spaces,
                onError: onError, onShowBalloon: onShowBalloon)
            return
        }

        // Regular space
        let switchMap = Space.buildSwitchIndexMap(for: spaces)
        let spaceID = spaces.first(
            where: { $0.spaceNumber == hitSpaceNumber }
        )?.spaceID ?? ""
        let tag = Space.switchTag(
            switchMapEntry: switchMap[spaceID],
            spaceNumber: hitSpaceNumber)
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: tag, context: ctx)
        executeStrategy(
            strategy, spaces: spaces,
            onError: onError, onShowBalloon: onShowBalloon)
    }
}
