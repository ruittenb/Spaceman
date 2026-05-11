//
//  SwitchOutcomeTests.swift
//  SpacemanTests
//
//  Created by René Uittenbogaard on 2026-05-11.
//  Co-author: Claude Code
//

import XCTest
@testable import Spaceman

final class SwitchOutcomeTests: XCTestCase {

    // MARK: - Helpers

    private func makeSpace(
        id: String, number: Int, displayID: String = "d1",
        current: Bool = false, fullScreen: Bool = false
    ) -> Space {
        Space(
            displayID: displayID, spaceID: id, spaceName: "",
            spaceNumber: number, spaceByDesktopID: "\(number)",
            isCurrentSpace: current, isFullScreen: fullScreen)
    }

    /// 5 desktops on d1, current=1. All have enabled shortcuts.
    private func standardSpaces() -> (spaces: [Space], enabledMap: [String: Int]) {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
            makeSpace(id: "s4", number: 4),
            makeSpace(id: "s5", number: 5),
        ]
        let enabledMap = ["s1": 1, "s2": 2, "s3": 3, "s4": 4, "s5": 5]
        return (spaces, enabledMap)
    }

    // MARK: - Desktop with shortcut, same display

    func testDesktopWithShortcut_sameDisplay_smooth() {
        let (spaces, enabledMap) = standardSpaces()
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .shortcutDirect(switchIndex: 3))
    }

    func testDesktopWithShortcut_sameDisplay_gesture() {
        let (spaces, enabledMap) = standardSpaces()
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .click, mode: .fast,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .gestureDirect(
                target: spaces[2], current: spaces[0], mode: .fast))
    }

    func testDesktopWithShortcut_sameDisplay_menu() {
        let (spaces, enabledMap) = standardSpaces()
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .menu, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .shortcutDirect(switchIndex: 3))
    }

    func testDesktopWithShortcut_sameDisplay_menuGesture() {
        let (spaces, enabledMap) = standardSpaces()
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .menu, mode: .instant,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .gestureDirect(
                target: spaces[2], current: spaces[0],
                mode: .instant))
    }

    // MARK: - Desktop with shortcut, cross-display

    func testDesktopWithShortcut_crossDisplay_smooth() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 2, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .shortcutDirect(switchIndex: 2))
    }

    func testDesktopWithShortcut_crossDisplay_gesture() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        // Gesture mode + cross display → falls through to shortcut
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 2, entryPoint: .click, mode: .fast,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .shortcutDirect(switchIndex: 2))
    }

    // MARK: - Desktop without shortcut, same display

    func testDesktopNoShortcut_sameDisplay_click_smooth() {
        // Desktop 3 exists but has no enabled shortcut
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let enabledMap = ["s1": 1, "s2": 2]  // s3 not enabled
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .showBalloon(.desktop))
    }

    func testDesktopNoShortcut_sameDisplay_gesture() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .click, mode: .fast,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .gestureDirect(
                target: spaces[2], current: spaces[0], mode: .fast))
    }

    func testDesktopNoShortcut_sameDisplay_menu_withArrows() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .menu, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        // Same display, 2 steps, arrows exist → chain from current
        XCTAssertEqual(
            outcome,
            .shortcutChain(steps: 2, goRight: true))
    }

    func testDesktopNoShortcut_sameDisplay_menu_noArrows() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .menu, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: false)
        XCTAssertEqual(outcome, .unreachable)
    }

    // MARK: - Desktop without shortcut, cross-display

    func testDesktopNoShortcut_crossDisplay_click() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
            makeSpace(id: "s3", number: 3, displayID: "d2"),
        ]
        let enabledMap = ["s1": 1, "s2": 2]  // s3 not enabled
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .showBalloon(.desktop))
    }

    func testDesktopNoShortcut_crossDisplay_menu_withAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
            makeSpace(id: "s3", number: 3, displayID: "d2"),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 3, entryPoint: .menu, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .shortcutJumpThenChain(
                anchorSwitchIndex: 2, steps: 1, goRight: true))
    }

    func testDesktopNoShortcut_crossDisplay_menu_noAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "f1", number: 2, displayID: "d2", fullScreen: true),
        ]
        // Only s1 has a shortcut, on d1. No anchor on d2.
        let enabledMap = ["s1": 1]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -2, entryPoint: .menu, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .unreachable)
    }

    // MARK: - Fullscreen, same display

    func testFullscreen_sameDisplay_smooth_chain() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "f1", number: 3, fullScreen: true),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -3, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .shortcutChain(steps: 2, goRight: true))
    }

    func testFullscreen_sameDisplay_gesture() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "f1", number: 2, fullScreen: true),
        ]
        let enabledMap = ["s1": 1]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -2, entryPoint: .click, mode: .instant,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .gestureDirect(
                target: spaces[1], current: spaces[0],
                mode: .instant))
    }

    func testFullscreen_sameDisplay_noArrows_click() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "f1", number: 2, fullScreen: true),
        ]
        let enabledMap = ["s1": 1]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -2, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: false)
        XCTAssertEqual(outcome, .showBalloon(.navigation))
    }

    func testFullscreen_sameDisplay_noArrows_menu() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "f1", number: 2, fullScreen: true),
        ]
        let enabledMap = ["s1": 1]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -2, entryPoint: .menu, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: false)
        XCTAssertEqual(outcome, .unreachable)
    }

    // MARK: - Fullscreen, cross-display

    func testFullscreen_crossDisplay_smooth_withAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
            makeSpace(id: "f1", number: 3, displayID: "d2", fullScreen: true),
        ]
        let enabledMap = ["s1": 1, "s2": 2]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -3, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(
            outcome,
            .shortcutJumpThenChain(
                anchorSwitchIndex: 2, steps: 1, goRight: true))
    }

    func testFullscreen_crossDisplay_click_noAnchor() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "f1", number: 2, displayID: "d2", fullScreen: true),
        ]
        let enabledMap = ["s1": 1]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -2, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .showBalloon(.navigation))
    }

    func testFullscreen_crossDisplay_gesture_noAnchor() {
        // Gesture + cross-display → falls through to shortcut logic → unreachable
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "f1", number: 2, displayID: "d2", fullScreen: true),
        ]
        let enabledMap = ["s1": 1]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -2, entryPoint: .click, mode: .fast,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .showBalloon(.navigation))
    }

    // MARK: - Navigation outcomes

    func testNavigation_missionControl() {
        let (spaces, _) = standardSpaces()
        let outcome = SpaceSwitcher.resolveNavigationOutcome(
            hitIndex: Space.missionControlIndex, mode: .smooth,
            spaces: spaces, hasArrowShortcuts: true,
            entryPoint: .click)
        XCTAssertEqual(outcome, .missionControl)
    }

    func testNavigation_next_smooth() {
        let (spaces, _) = standardSpaces()
        let outcome = SpaceSwitcher.resolveNavigationOutcome(
            hitIndex: Space.nextSpaceIndex, mode: .smooth,
            spaces: spaces, hasArrowShortcuts: true,
            entryPoint: .click)
        XCTAssertEqual(outcome, .shortcutRelative(goRight: true))
    }

    func testNavigation_prev_gesture() {
        let (spaces, _) = standardSpaces()
        let outcome = SpaceSwitcher.resolveNavigationOutcome(
            hitIndex: Space.previousSpaceIndex, mode: .fast,
            spaces: spaces, hasArrowShortcuts: true,
            entryPoint: .click)
        XCTAssertEqual(
            outcome,
            .gestureRelative(goRight: false, mode: .fast))
    }

    func testNavigation_atEdge_unreachable() {
        // Current is space 5 (last), next → at edge
        let spaces = [
            makeSpace(id: "s1", number: 1),
            makeSpace(id: "s5", number: 5, current: true),
        ]
        let outcome = SpaceSwitcher.resolveNavigationOutcome(
            hitIndex: Space.nextSpaceIndex, mode: .smooth,
            spaces: spaces, hasArrowShortcuts: true,
            entryPoint: .click)
        XCTAssertEqual(outcome, .unreachable)
    }

    func testNavigation_noArrows_click_showsBalloon() {
        let (spaces, _) = standardSpaces()
        let outcome = SpaceSwitcher.resolveNavigationOutcome(
            hitIndex: Space.nextSpaceIndex, mode: .smooth,
            spaces: spaces, hasArrowShortcuts: false,
            entryPoint: .click)
        XCTAssertEqual(outcome, .showBalloon(.navigation))
    }

    func testNavigation_noArrows_menu_unreachable() {
        let (spaces, _) = standardSpaces()
        let outcome = SpaceSwitcher.resolveNavigationOutcome(
            hitIndex: Space.nextSpaceIndex, mode: .smooth,
            spaces: spaces, hasArrowShortcuts: false,
            entryPoint: .menu)
        XCTAssertEqual(outcome, .unreachable)
    }

    // MARK: - Edge cases

    func testNoCurrentSpace_unreachable() {
        let spaces = [makeSpace(id: "s1", number: 1)]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: 1, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: ["s1": 1],
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .unreachable)
    }

    func testNoTargetSpace_unreachable() {
        let spaces = [makeSpace(id: "s1", number: 1, current: true)]
        let outcome = SpaceSwitcher.resolveOutcome(
            switchTag: -99, entryPoint: .click, mode: .smooth,
            spaces: spaces, enabledSwitchMap: ["s1": 1],
            hasArrowShortcuts: true)
        XCTAssertEqual(outcome, .unreachable)
    }
}
