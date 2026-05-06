//
//  ChainingStrategyTests.swift
//  SpacemanTests
//
//  Created by René Uittenbogaard on 2026-05-05.
//  Co-author: Claude Code
//

import XCTest
@testable import Spaceman

final class ChainingStrategyTests: XCTestCase {

    /// Helper: creates spaces on a single display.
    /// Desktops 1–N are regular, any beyond that can be fullscreen.
    private func makeSpaces(
        desktops: Int, fullscreen: Int = 0,
        currentNumber: Int = 1
    ) -> [Space] {
        var spaces: [Space] = []
        for i in 1...desktops {
            spaces.append(Space(
                displayID: "d1", spaceID: "s\(i)", spaceName: "",
                spaceNumber: i, spaceByDesktopID: "\(i)",
                isCurrentSpace: i == currentNumber,
                isFullScreen: false))
        }
        for i in 1...max(1, fullscreen) {
            guard fullscreen > 0 else { break }
            let num = desktops + i
            spaces.append(Space(
                displayID: "d1", spaceID: "f\(i)", spaceName: "",
                spaceNumber: num, spaceByDesktopID: "F\(i)",
                isCurrentSpace: num == currentNumber,
                isFullScreen: true))
        }
        return spaces
    }

    // MARK: - Chain from current position

    func testChainFromCurrent_closerThanAnchor() {
        // 5 desktops, current=3, target=5
        // From current: 2 steps. From anchor (d5=desktop 5): 0 steps
        // but d5 IS the target, so anchor route = jump to 5 directly.
        // Actually let's use a target beyond max switchable.
        // 18 desktops, current=16, target=18 (no shortcut for 17, 18)
        let spaces = makeSpaces(desktops: 18, currentNumber: 16)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 18, spaces: spaces)

        // From current (16): 2 steps right
        // From anchor (16, desktop 16): 2 steps right
        // arrowsFromCurrent (2) <= arrowsFromAnchor (2) + 1
        XCTAssertEqual(
            strategy,
            .chainFromCurrent(steps: 2, goRight: true))
    }

    func testChainFromCurrent_goLeft() {
        // 18 desktops, current=18, target=17
        let spaces = makeSpaces(desktops: 18, currentNumber: 18)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 17, spaces: spaces)

        XCTAssertEqual(
            strategy,
            .chainFromCurrent(steps: 1, goRight: false))
    }

    // MARK: - Jump then chain

    func testJumpThenChain_anchorCloserThanCurrent() {
        // 20 desktops, current=1, target=18
        // From current: 17 steps
        // From anchor (desktop 16): 2 steps + 1 jump = 3 waits
        let spaces = makeSpaces(desktops: 20, currentNumber: 1)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 18, spaces: spaces)

        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 16, steps: 2, goRight: true))
    }

    func testJumpThenChain_leftward() {
        // 20 desktops, current=20, target=17
        // From current: 3 steps
        // From anchor (desktop 16): 1 step left + 1 jump = 2 waits
        // arrowsFromCurrent (3) > arrowsFromAnchor (1) + 1
        let spaces = makeSpaces(desktops: 20, currentNumber: 20)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 17, spaces: spaces)

        // Anchor is desktop 16 (switch index 16), needs 1 right
        // Wait, 17 > 16, so goRight = true
        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 16, steps: 1, goRight: true))
    }

    // MARK: - Direct switch

    func testDirectSwitch_anchorIsTarget() {
        // 20 desktops, current=1, target=16
        // Desktop 16 has a shortcut, so it's directly switchable
        // But wait — target 16 has a switch index, so it wouldn't
        // go through chaining at all. Let's set up a scenario where
        // the nearest anchor happens to be the target.
        // Actually this tests the edge case in calculateChainingStrategy
        // where delta == 0.

        // Make target = desktop 16 (switch index 16), current on d2=1
        let spaces = makeSpaces(desktops: 20, currentNumber: 20)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 16, spaces: spaces)

        // From current (20): 4 steps
        // Anchor 16 is the target itself (delta=0)
        // arrowsFromCurrent (4) > arrowsFromAnchor (0) + 1
        XCTAssertEqual(
            strategy, .directSwitch(switchIndex: 16))
    }

    // MARK: - Fullscreen spaces

    func testFullscreen_chainFromCurrent() {
        // 9 desktops + 1 fullscreen (F1 at position 10)
        // Current = 9, target = 10 (F1)
        let spaces = makeSpaces(
            desktops: 9, fullscreen: 1, currentNumber: 9)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 10, spaces: spaces)

        // From current: 1 step right
        // From anchor (desktop 9): 1 step + 1 jump
        // arrowsFromCurrent (1) <= arrowsFromAnchor (1) + 1
        XCTAssertEqual(
            strategy,
            .chainFromCurrent(steps: 1, goRight: true))
    }

    // MARK: - Cross-display

    func testCrossDisplay_usesAnchorOnTargetDisplay() {
        // Two displays: d1 has desktops 1-5 (current=1),
        // d2 has desktops 6-10. Target=8 (on d2).
        var spaces: [Space] = []
        for i in 1...5 {
            spaces.append(Space(
                displayID: "d1", spaceID: "s\(i)", spaceName: "",
                spaceNumber: i, spaceByDesktopID: "\(i)",
                isCurrentSpace: i == 1, isFullScreen: false))
        }
        for i in 6...10 {
            spaces.append(Space(
                displayID: "d2", spaceID: "s\(i)", spaceName: "",
                spaceNumber: i, spaceByDesktopID: "\(i - 5)",
                isCurrentSpace: false, isFullScreen: false))
        }
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 8, spaces: spaces)

        // Current is on d1, target on d2 → arrowsFromCurrent = max
        // Anchor on d2: desktop 8 has switch index 8 (≤16)
        // delta = 0 → directSwitch
        XCTAssertEqual(strategy, .directSwitch(switchIndex: 8))
    }

    // MARK: - Edge cases

    func testUnreachable_noSpacesMatchTarget() {
        let spaces = makeSpaces(desktops: 3, currentNumber: 1)
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 99, spaces: spaces)

        XCTAssertEqual(strategy, .unreachable)
    }

    func testUnreachable_noCurrentSpace() {
        let spaces = [
            Space(
                displayID: "d1", spaceID: "s1", spaceName: "",
                spaceNumber: 1, spaceByDesktopID: "1",
                isCurrentSpace: false, isFullScreen: false)
        ]
        let strategy = SpaceSwitcher.calculateChainingStrategy(
            targetSpaceNumber: 1, spaces: spaces)

        XCTAssertEqual(strategy, .unreachable)
    }
}
