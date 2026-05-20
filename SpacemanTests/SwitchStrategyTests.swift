//
//  SwitchStrategyTests.swift
//  SpacemanTests
//
//  Created by René Uittenbogaard on 2026-05-11.
//  Co-author: Claude Code
//

import XCTest
@testable import Spaceman

final class SwitchStrategyTests: XCTestCase {

    // MARK: - Helpers

    private func makeSpace(
        id: String, number: Int, displayID: String = "d1",
        current: Bool = false, fullScreen: Bool = false
    ) -> Space {
        Space(
            displayID: displayID, spaceID: id, spaceName: "",
            spaceNumber: number, spaceLabel: "\(number)",
            isCurrentSpace: current, isFullScreen: fullScreen)
    }

    private func ctx(
        entryPoint: SwitchEntryPoint = .click,
        mode: SwitchingMode = .smooth,
        spaces: [Space],
        enabledSwitchMap: [String: Int],
        hasArrowShortcuts: Bool = true,
        focusedDisplayID: String? = nil
    ) -> SwitchContext {
        SwitchContext(
            entryPoint: entryPoint, mode: mode,
            spaces: spaces, enabledSwitchMap: enabledSwitchMap,
            hasArrowShortcuts: hasArrowShortcuts,
            focusedDisplayID: focusedDisplayID)
    }

    /// 5 desktops on d1, current=1. All have enabled shortcuts.
    private func standardSpaces(
    ) -> (spaces: [Space], enabledMap: [String: Int]) {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
            makeSpace(id: "s4", number: 4),
            makeSpace(id: "s5", number: 5),
        ]
        let enabledMap = [
            "s1": 1, "s2": 2, "s3": 3, "s4": 4, "s5": 5]
        return (spaces, enabledMap)
    }

    // MARK: - Desktop with shortcut, same display

    func testDesktopWithShortcut_sameDisplay_smooth() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap))
        XCTAssertEqual(strategy, .shortcutDirect(switchIndex: 3))
    }

    func testDesktopWithShortcut_sameDisplay_gesture() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: enabledMap))
        XCTAssertEqual(
            strategy,
            .gestureDirect(
                target: spaces[2], current: spaces[0],
                mode: .fast))
    }

    func testDesktopWithShortcut_sameDisplay_menu() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: enabledMap))
        XCTAssertEqual(strategy, .shortcutDirect(switchIndex: 3))
    }

    func testDesktopWithShortcut_sameDisplay_menuGesture() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                entryPoint: .menu, mode: .instant,
                spaces: spaces, enabledSwitchMap: enabledMap))
        XCTAssertEqual(
            strategy,
            .gestureDirect(
                target: spaces[2], current: spaces[0],
                mode: .instant))
    }

    // MARK: - Desktop with shortcut, cross-display

    func testDesktopWithShortcut_crossDisplay_smooth() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 2,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(strategy, .shortcutDirect(switchIndex: 2))
    }

    func testDesktopWithShortcut_crossDisplay_gesture() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 2,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2],
                focusedDisplayID: "d1"))
        XCTAssertEqual(strategy, .shortcutDirect(switchIndex: 2))
    }

    func testDesktopWithShortcut_sameDisplay_gesture_withFocusedID() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: enabledMap,
                focusedDisplayID: "d1"))
        XCTAssertEqual(
            strategy,
            .gestureDirect(
                target: spaces[2], current: spaces[0],
                mode: .fast))
    }

    // MARK: - Desktop without shortcut, same display

    func testDesktopNoShortcut_sameDisplay_click_smooth() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(strategy, .showBalloon(.desktop))
    }

    func testDesktopNoShortcut_sameDisplay_gesture() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2],
                focusedDisplayID: "d1"))
        XCTAssertEqual(
            strategy,
            .gestureDirect(
                target: spaces[2], current: spaces[0],
                mode: .fast))
    }

    func testDesktopNoShortcut_sameDisplay_menu_withArrows() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(
            strategy,
            .shortcutChain(steps: 2, goRight: true))
    }

    func testDesktopNoShortcut_sameDisplay_menu_noArrows() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2],
                hasArrowShortcuts: false))
        XCTAssertEqual(strategy, .unreachable)
    }

    // MARK: - Desktop without shortcut, cross-display

    func testDesktopNoShortcut_crossDisplay_click() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
            makeSpace(id: "s3", number: 3, displayID: "d2"),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(strategy, .showBalloon(.desktop))
    }

    func testDesktopNoShortcut_crossDisplay_menu_withAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
            makeSpace(id: "s3", number: 3, displayID: "d2"),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 3,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(
            strategy,
            .shortcutJumpThenChain(
                anchorSwitchIndex: 2, steps: 1, goRight: true))
    }

    func testDesktopNoShortcut_crossDisplay_menu_noAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "f1", number: 2, displayID: "d2",
                      fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -2,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: ["s1": 1]))
        XCTAssertEqual(strategy, .unreachable)
    }

    // MARK: - Fullscreen, same display

    func testFullscreen_sameDisplay_smooth_chain() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "f1", number: 3, fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -3,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(
            strategy,
            .shortcutChain(steps: 2, goRight: true))
    }

    func testFullscreen_sameDisplay_gesture() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "f1", number: 2, fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -2,
            context: ctx(
                mode: .instant, spaces: spaces,
                enabledSwitchMap: ["s1": 1]))
        XCTAssertEqual(
            strategy,
            .gestureDirect(
                target: spaces[1], current: spaces[0],
                mode: .instant))
    }

    func testFullscreen_sameDisplay_noArrows_click() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "f1", number: 2, fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -2,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1],
                hasArrowShortcuts: false))
        XCTAssertEqual(strategy, .showBalloon(.navigation))
    }

    func testFullscreen_sameDisplay_noArrows_menu() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "f1", number: 2, fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -2,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: ["s1": 1],
                hasArrowShortcuts: false))
        XCTAssertEqual(strategy, .unreachable)
    }

    // Fullscreen same display, jump-then-chain scenarios:
    // anchor is closer to target than current position.

    func testFullscreen_sameDisplay_click_gestureJumpThenChain() {
        // 9 desktops + 2 fullscreen. Current=1, target=F2 (pos 11).
        // From current: 10 steps. From anchor (desktop 9): 2 steps.
        // Same display → gestureJumpThenChain.
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
            makeSpace(id: "s4", number: 4),
            makeSpace(id: "s5", number: 5),
            makeSpace(id: "s6", number: 6),
            makeSpace(id: "s7", number: 7),
            makeSpace(id: "s8", number: 8),
            makeSpace(id: "s9", number: 9),
            makeSpace(
                id: "f1", number: 10, fullScreen: true),
            makeSpace(
                id: "f2", number: 11, fullScreen: true),
        ]
        let enabledMap = Dictionary(
            uniqueKeysWithValues: (1...9).map {
                ("s\($0)", $0)
            })
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -11,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: enabledMap))
        XCTAssertEqual(
            strategy,
            .gestureJumpThenChain(
                anchor: spaces[8], current: spaces[0],
                steps: 2, goRight: true))
    }

    func testFullscreen_sameDisplay_menu_gestureJumpThenChain() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
            makeSpace(id: "s4", number: 4),
            makeSpace(id: "s5", number: 5),
            makeSpace(id: "s6", number: 6),
            makeSpace(id: "s7", number: 7),
            makeSpace(id: "s8", number: 8),
            makeSpace(id: "s9", number: 9),
            makeSpace(
                id: "f1", number: 10, fullScreen: true),
            makeSpace(
                id: "f2", number: 11, fullScreen: true),
        ]
        let enabledMap = Dictionary(
            uniqueKeysWithValues: (1...9).map {
                ("s\($0)", $0)
            })
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -11,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: enabledMap))
        XCTAssertEqual(
            strategy,
            .gestureJumpThenChain(
                anchor: spaces[8], current: spaces[0],
                steps: 2, goRight: true))
    }

    func testDesktopNoShortcut_sameDisplay_menu_gestureJumpThenChain() {
        // 5 desktops, only s1 and s3 have shortcuts. Current=1, target=5.
        // From current: 4 steps. From anchor (s3): 2 steps.
        // Same display → gestureJumpThenChain.
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
            makeSpace(id: "s4", number: 4),
            makeSpace(id: "s5", number: 5),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 5,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s3": 3]))
        XCTAssertEqual(
            strategy,
            .gestureJumpThenChain(
                anchor: spaces[2], current: spaces[0],
                steps: 2, goRight: true))
    }

    // MARK: - Fullscreen, cross-display

    func testFullscreen_crossDisplay_smooth_withAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
            makeSpace(id: "f1", number: 3, displayID: "d2",
                      fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -3,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2]))
        XCTAssertEqual(
            strategy,
            .shortcutJumpThenChain(
                anchorSwitchIndex: 2, steps: 1, goRight: true))
    }

    func testFullscreen_crossDisplay_click_noAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "f1", number: 2, displayID: "d2",
                      fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -2,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1]))
        XCTAssertEqual(strategy, .showBalloon(.navigation))
    }

    func testFullscreen_crossDisplay_gesture_noAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "f1", number: 2, displayID: "d2",
                      fullScreen: true),
        ]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -2,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: ["s1": 1],
                focusedDisplayID: "d1"))
        XCTAssertEqual(strategy, .showBalloon(.navigation))
    }

    // MARK: - Navigation strategies

    func testNavigation_missionControl() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.missionControlIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap))
        XCTAssertEqual(strategy, .missionControl)
    }

    func testNavigation_next_smooth() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.nextSpaceIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap))
        XCTAssertEqual(
            strategy, .shortcutRelative(goRight: true))
    }

    func testNavigation_prev_gesture() {
        // Current=3 so there's room to go left
        let spaces = [
            makeSpace(id: "s1", number: 1),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3, current: true),
        ]
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.previousSpaceIndex,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: [:]))
        XCTAssertEqual(
            strategy,
            .gestureRelative(goRight: false, mode: .fast))
    }

    func testNavigation_atEdge_unreachable() {
        let spaces = [
            makeSpace(id: "s1", number: 1),
            makeSpace(id: "s5", number: 5, current: true),
        ]
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.nextSpaceIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: [:]))
        XCTAssertEqual(strategy, .unreachable)
    }

    func testNavigation_noArrows_click_showsBalloon() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.nextSpaceIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap,
                hasArrowShortcuts: false))
        XCTAssertEqual(strategy, .showBalloon(.navigation))
    }

    func testNavigation_noArrows_menu_unreachable() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.nextSpaceIndex,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: enabledMap,
                hasArrowShortcuts: false))
        XCTAssertEqual(strategy, .unreachable)
    }

    // MARK: - Edge cases

    func testNoCurrentSpace_unreachable() {
        let spaces = [makeSpace(id: "s1", number: 1)]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: 1,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1]))
        XCTAssertEqual(strategy, .unreachable)
    }

    func testNoTargetSpace_unreachable() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true)]
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -99,
            context: ctx(
                spaces: spaces,
                enabledSwitchMap: ["s1": 1]))
        XCTAssertEqual(strategy, .unreachable)
    }
}
