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
        XCTAssertEqual(strategy, .unreachable)
    }

    func testDesktopNoShortcut_crossDisplay_menu_noAnchor() {
        // No desktop on d2 has an enabled shortcut
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
                enabledSwitchMap: ["s1": 1]))
        XCTAssertEqual(strategy, .unreachable)
    }

    // MARK: - Desktop beyond maxSwitchableDesktop (no shortcut possible)

    /// 18 desktops on d1 (current=16); desktops 17 and 18 get negative tags.
    private func eighteenDesktops(
    ) -> (spaces: [Space], enabledMap: [String: Int]) {
        let spaces = (1...18).map {
            makeSpace(id: "s\($0)", number: $0, current: $0 == 16)
        }
        return (spaces, Space.buildSwitchIndexMap(for: spaces))
    }

    func testDesktopBeyondMax_sameDisplay_click_chains() {
        // No shortcut can be configured for desktop 18, so a click
        // chains instead of showing the "configure shortcuts" balloon.
        let (spaces, enabledMap) = eighteenDesktops()
        let tag = Space.switchTag(
            switchMapEntry: enabledMap["s18"], spaceNumber: 18)
        XCTAssertEqual(tag, -18)
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: tag,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap,
                focusedDisplayID: "d1"))
        XCTAssertEqual(
            strategy,
            .shortcutChain(steps: 2, goRight: true))
    }

    func testDesktopBeyondMax_crossDisplay_click_shortcutJumpThenChain() {
        // d1: desktop 1 (current, focused). d2: desktops 2-19.
        // Target = desktop 19 (no shortcut). Nearest anchor on d2 = 16.
        var spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true)
        ]
        spaces += (2...19).map {
            makeSpace(id: "s\($0)", number: $0, displayID: "d2",
                      current: $0 == 2)
        }
        let enabledMap = Space.buildSwitchIndexMap(for: spaces)
        let strategy = SwitchStrategizer.resolveStrategy(
            switchTag: -19,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap,
                focusedDisplayID: "d1"))
        XCTAssertEqual(
            strategy,
            .shortcutJumpThenChain(
                anchorSwitchIndex: 16, steps: 3, goRight: true))
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

    func testFullscreen_crossDisplay_unreachable_evenWithAnchor() {
        // Fullscreen spaces have no shortcut, and arrows and gestures only
        // act on the focused display → blink, for every entry point and
        // mode, even though d2 has an anchor (s2).
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2",
                      current: true),
            makeSpace(id: "f1", number: 3, displayID: "d2",
                      fullScreen: true),
        ]
        for entryPoint: SwitchEntryPoint in [.click, .menu] {
            for mode: SwitchingMode in [.smooth, .fast, .instant] {
                let strategy = SwitchStrategizer.resolveStrategy(
                    switchTag: -3,
                    context: ctx(
                        entryPoint: entryPoint, mode: mode,
                        spaces: spaces,
                        enabledSwitchMap: ["s1": 1, "s2": 2],
                        focusedDisplayID: "d1"))
                XCTAssertEqual(
                    strategy, .unreachable, "\(entryPoint) \(mode)")
            }
        }
    }

    // MARK: - Two displays, each with a current space

    /// d1: s1 (current), s2. d2: s3 (current), s4.
    private func twoDisplaysWithCurrents() -> [Space] {
        [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d1"),
            makeSpace(id: "s3", number: 3, displayID: "d2",
                      current: true),
            makeSpace(id: "s4", number: 4, displayID: "d2"),
        ]
    }

    func testTwoDisplays_gesture_usesCurrentOfFocusedDisplay() {
        let spaces = twoDisplaysWithCurrents()
        let enabledMap = ["s1": 1, "s2": 2, "s3": 3, "s4": 4]

        let focusedOnTarget = SwitchStrategizer.resolveStrategy(
            switchTag: 4,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: enabledMap,
                focusedDisplayID: "d2"))
        XCTAssertEqual(
            focusedOnTarget,
            .gestureDirect(
                target: spaces[3], current: spaces[2], mode: .fast))

        // Focus on the other display → gestures can't reach it
        let focusedElsewhere = SwitchStrategizer.resolveStrategy(
            switchTag: 4,
            context: ctx(
                mode: .fast, spaces: spaces,
                enabledSwitchMap: enabledMap,
                focusedDisplayID: "d1"))
        XCTAssertEqual(focusedElsewhere, .shortcutDirect(switchIndex: 4))
    }

    func testTwoDisplays_smooth_menu_chainsFromCurrentOfFocusedDisplay() {
        // s4 has no shortcut. Focus on d2 → chain 1 right from s3.
        let spaces = twoDisplaysWithCurrents()
        let enabledMap = ["s1": 1, "s2": 2, "s3": 3]

        let focusedOnTarget = SwitchStrategizer.resolveStrategy(
            switchTag: 4,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: enabledMap,
                focusedDisplayID: "d2"))
        XCTAssertEqual(
            focusedOnTarget,
            .shortcutChain(steps: 1, goRight: true))

        // Focus on d1 → cross-display desktop without shortcut → greyed out
        let focusedElsewhere = SwitchStrategizer.resolveStrategy(
            switchTag: 4,
            context: ctx(
                entryPoint: .menu, spaces: spaces,
                enabledSwitchMap: enabledMap,
                focusedDisplayID: "d1"))
        XCTAssertEqual(focusedElsewhere, .unreachable)
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

    func testNavigation_prev_atFirstSpace_unreachable() {
        let (spaces, enabledMap) = standardSpaces()
        let strategy = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.previousSpaceIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: enabledMap))
        XCTAssertEqual(strategy, .unreachable)
    }

    func testNavigation_atEdge_gesture_unreachable() {
        let spaces = [
            makeSpace(id: "s1", number: 1),
            makeSpace(id: "s2", number: 2, current: true),
        ]
        for mode: SwitchingMode in [.fast, .instant] {
            let strategy = SwitchStrategizer.resolveNavigationStrategy(
                hitIndex: Space.nextSpaceIndex,
                context: ctx(
                    mode: mode, spaces: spaces, enabledSwitchMap: [:]))
            XCTAssertEqual(strategy, .unreachable, "\(mode)")
        }
    }

    /// d1: s1 (current), s2, s3. d2: s4, s5 (current).
    /// d1's current is at its first position, d2's current at its last.
    private func twoDisplaysForEdges() -> [Space] {
        [
            makeSpace(id: "s1", number: 1, displayID: "d1",
                      current: true),
            makeSpace(id: "s2", number: 2, displayID: "d1"),
            makeSpace(id: "s3", number: 3, displayID: "d1"),
            makeSpace(id: "s4", number: 4, displayID: "d2"),
            makeSpace(id: "s5", number: 5, displayID: "d2",
                      current: true),
        ]
    }

    func testIsAtEdge_usesCurrentOfFocusedDisplay() {
        let spaces = twoDisplaysForEdges()

        XCTAssertTrue(SwitchStrategizer.isAtEdge(
            spaces: spaces, goingRight: true, focusedDisplayID: "d2"))
        XCTAssertFalse(SwitchStrategizer.isAtEdge(
            spaces: spaces, goingRight: false, focusedDisplayID: "d2"))

        // Without a focused display, the first current space (d1) is used
        XCTAssertFalse(SwitchStrategizer.isAtEdge(
            spaces: spaces, goingRight: true))
        XCTAssertTrue(SwitchStrategizer.isAtEdge(
            spaces: spaces, goingRight: false))
    }

    func testNavigation_twoDisplays_focusOnSecond() {
        let spaces = twoDisplaysForEdges()

        let next = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.nextSpaceIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: [:],
                focusedDisplayID: "d2"))
        XCTAssertEqual(next, .unreachable)

        // d1's current is at its first position, but d2 has focus
        let previous = SwitchStrategizer.resolveNavigationStrategy(
            hitIndex: Space.previousSpaceIndex,
            context: ctx(
                spaces: spaces, enabledSwitchMap: [:],
                focusedDisplayID: "d2"))
        XCTAssertEqual(previous, .shortcutRelative(goRight: false))
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

// MARK: - AppleScript target resolution

final class ScriptSpaceResolverTests: XCTestCase {

    private func makeSpace(
        id: String, number: Int, name: String = "", displayID: String = "d1",
        current: Bool = false, fullScreen: Bool = false
    ) -> Space {
        Space(
            displayID: displayID, spaceID: id, spaceName: name,
            spaceNumber: number, spaceLabel: "\(number)",
            isCurrentSpace: current, isFullScreen: fullScreen)
    }

    /// d1: Mail(1), Code(2), Safari fullscreen(3); d2: Chat(4), Mail(5)
    private func twoDisplaySpaces() -> [Space] {
        [
            makeSpace(id: "s1", number: 1, name: "Mail", current: true),
            makeSpace(id: "s2", number: 2, name: "Code"),
            makeSpace(id: "s3", number: 3, name: "Safari", fullScreen: true),
            makeSpace(id: "s4", number: 4, name: "Chat", displayID: "d2", current: true),
            makeSpace(id: "s5", number: 5, name: "Mail", displayID: "d2")
        ]
    }

    private func resolve(
        number: Int? = nil, name: String? = nil, displayNumber: Int? = nil
    ) -> String? {
        ScriptSpaceResolver.resolve(
            spaces: twoDisplaySpaces(), displayIDs: ["d1", "d2"],
            number: number, name: name, displayNumber: displayNumber)?.spaceID
    }

    func testByGlobalNumber() {
        XCTAssertEqual(resolve(number: 2), "s2")
        XCTAssertEqual(resolve(number: 4), "s4")
    }

    func testUnknownNumber() {
        XCTAssertNil(resolve(number: 0))
        XCTAssertNil(resolve(number: 6))
    }

    func testByName_caseInsensitive() {
        XCTAssertEqual(resolve(name: "code"), "s2")
        XCTAssertEqual(resolve(name: "CHAT"), "s4")
    }

    func testByName_firstDuplicateWins() {
        XCTAssertEqual(resolve(name: "Mail"), "s1")
    }

    func testByName_fullscreenAppName() {
        XCTAssertEqual(resolve(name: "safari"), "s3")
    }

    func testUnknownName() {
        XCTAssertNil(resolve(name: "Nope"))
        XCTAssertNil(resolve(name: ""))
    }

    func testNumberOnDisplay() {
        XCTAssertEqual(resolve(number: 1, displayNumber: 2), "s4")
        XCTAssertEqual(resolve(number: 2, displayNumber: 2), "s5")
        XCTAssertEqual(resolve(number: 3, displayNumber: 1), "s3")
        XCTAssertNil(resolve(number: 3, displayNumber: 2))
        XCTAssertNil(resolve(number: 0, displayNumber: 1))
    }

    func testNameOnDisplay() {
        XCTAssertEqual(resolve(name: "Mail", displayNumber: 2), "s5")
        XCTAssertNil(resolve(name: "Code", displayNumber: 2))
    }

    func testDisplayOutOfRange() {
        XCTAssertNil(resolve(number: 1, displayNumber: 0))
        XCTAssertNil(resolve(number: 1, displayNumber: 3))
    }

    func testSwitchingModeCodes() {
        XCTAssertEqual(ScriptSpaceResolver.switchingMode(
            fromEnumCode: ScriptSpaceResolver.fourCharCode("Msmo")), .smooth)
        XCTAssertEqual(ScriptSpaceResolver.switchingMode(
            fromEnumCode: ScriptSpaceResolver.fourCharCode("Mfst")), .fast)
        XCTAssertEqual(ScriptSpaceResolver.switchingMode(
            fromEnumCode: ScriptSpaceResolver.fourCharCode("Mins")), .instant)
        XCTAssertNil(ScriptSpaceResolver.switchingMode(
            fromEnumCode: ScriptSpaceResolver.fourCharCode("Mxxx")))
    }

    func testFourCharCode() {
        // 'Msmo' = 0x4D736D6F
        XCTAssertEqual(ScriptSpaceResolver.fourCharCode("Msmo"), 0x4D73_6D6F)
    }
}
