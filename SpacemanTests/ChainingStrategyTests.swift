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
                spaceNumber: i, spaceLabel: "\(i)",
                isCurrentSpace: i == currentNumber,
                isFullScreen: false))
        }
        for i in 1...max(1, fullscreen) {
            guard fullscreen > 0 else { break }
            let num = desktops + i
            spaces.append(Space(
                displayID: "d1", spaceID: "f\(i)", spaceName: "",
                spaceNumber: num, spaceLabel: "F\(i)",
                isCurrentSpace: num == currentNumber,
                isFullScreen: true))
        }
        return spaces
    }

    // MARK: - Chain from current position

    func testChainFromCurrent_currentIsNearestAnchor() {
        // 18 desktops, current=16, target=18 (no shortcut for 17, 18).
        // The nearest anchor (desktop 16) is the current space itself,
        // so both routes need 2 arrows; chaining from current avoids the jump.
        let spaces = makeSpaces(desktops: 18, currentNumber: 16)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 18, spaces: spaces)

        // arrowsFromCurrent (2) <= arrowsFromAnchor (2) + 1
        XCTAssertEqual(
            strategy,
            .chainFromCurrent(steps: 2, goRight: true))
    }

    // MARK: - Chain-vs-jump boundary (arrowsFromCurrent <= arrowsFromAnchor + 1)

    func testBoundary_currentOneMoreThanAnchor_chains() {
        // 10 desktops, current=1, target=4. Only desktop 6 has a shortcut.
        // From current: 3 arrows. From anchor: 2 arrows + 1 jump.
        // arrowsFromCurrent (3) == arrowsFromAnchor (2) + 1 → chain.
        let spaces = makeSpaces(desktops: 10, currentNumber: 1)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 4, spaces: spaces, switchMap: ["s6": 6])

        XCTAssertEqual(
            strategy,
            .chainFromCurrent(steps: 3, goRight: true))
    }

    func testBoundary_currentTwoMoreThanAnchor_jumps() {
        // 10 desktops, current=1, target=4. Only desktop 5 has a shortcut.
        // From current: 3 arrows. From anchor: 1 arrow + 1 jump.
        // arrowsFromCurrent (3) > arrowsFromAnchor (1) + 1 → jump.
        let spaces = makeSpaces(desktops: 10, currentNumber: 1)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 4, spaces: spaces, switchMap: ["s5": 5])

        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 5, steps: 1, goRight: false))
    }

    func testChainFromCurrent_goLeft() {
        // 18 desktops, current=18, target=17
        let spaces = makeSpaces(desktops: 18, currentNumber: 18)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
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
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 18, spaces: spaces)

        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 16, steps: 2, goRight: true))
    }

    func testJumpThenChain_currentRightOfTarget_chainsRight() {
        // 20 desktops, current=20, target=17
        // From current: 3 steps left
        // From anchor (desktop 16): 1 step right + 1 jump
        // arrowsFromCurrent (3) > arrowsFromAnchor (1) + 1
        let spaces = makeSpaces(desktops: 20, currentNumber: 20)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 17, spaces: spaces)

        // The anchor is left of the target, so the chain after the
        // jump goes right, although the current space is to the right.
        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 16, steps: 1, goRight: true))
    }

    func testJumpThenChain_leftward() {
        // 10 desktops, current=1, target=8. Shortcuts for desktops 1 and 10.
        // From current: 7 steps. From anchor (desktop 10): 2 steps left.
        // arrowsFromCurrent (7) > arrowsFromAnchor (2) + 1
        let spaces = makeSpaces(desktops: 10, currentNumber: 1)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 8, spaces: spaces,
            switchMap: ["s1": 1, "s10": 10])

        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 10, steps: 2, goRight: false))
    }

    // MARK: - Nearest anchor tie-break

    func testFindNearestAnchor_tie_prefersAnchorAlongTheWay() {
        // 9 desktops, shortcuts for desktops 3 and 7, target=5.
        // Both anchors are 2 away; prefer the one between current and target.
        let spaces = makeSpaces(desktops: 9, currentNumber: 1)
        let switchMap = ["s3": 3, "s7": 7]

        let goingRightAnchor = SwitchStrategizer.findNearestAnchor(
            targetSpaceNumber: 5, currentSpaceNumber: 1,
            spaces: spaces, switchMap: switchMap)
        XCTAssertEqual(goingRightAnchor?.spaceID, "s3")

        let goingLeftAnchor = SwitchStrategizer.findNearestAnchor(
            targetSpaceNumber: 5, currentSpaceNumber: 9,
            spaces: spaces, switchMap: switchMap)
        XCTAssertEqual(goingLeftAnchor?.spaceID, "s7")
    }

    // MARK: - Direct switch

    func testDirectSwitch_anchorIsTarget() {
        // 20 desktops, current=20, target=16.
        // Desktop 16 has a shortcut, so the nearest anchor is the
        // target itself (delta == 0). In the app such a target never
        // reaches chaining; this covers the delta == 0 branch.
        let spaces = makeSpaces(desktops: 20, currentNumber: 20)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
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
        let strategy = SwitchStrategizer.calculateChainingStrategy(
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
                spaceNumber: i, spaceLabel: "\(i)",
                isCurrentSpace: i == 1, isFullScreen: false))
        }
        for i in 6...10 {
            spaces.append(Space(
                displayID: "d2", spaceID: "s\(i)", spaceName: "",
                spaceNumber: i, spaceLabel: "\(i - 5)",
                isCurrentSpace: false, isFullScreen: false))
        }
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 8, spaces: spaces)

        // Current is on d1, target on d2 → arrowsFromCurrent = max
        // Anchor on d2: desktop 8 has switch index 8 (≤16)
        // delta = 0 → directSwitch
        XCTAssertEqual(strategy, .directSwitch(switchIndex: 8))
    }

    func testFocusedDisplay_decidesWhetherToChainFromCurrent() {
        // d1: desktops 1-3 (current=1), d2: desktops 4-6 (current=4).
        // Target=6 on d2; only desktops 1-4 have shortcuts (anchor = 4).
        var spaces: [Space] = []
        for i in 1...6 {
            spaces.append(Space(
                displayID: i <= 3 ? "d1" : "d2", spaceID: "s\(i)",
                spaceName: "", spaceNumber: i, spaceLabel: "\(i)",
                isCurrentSpace: i == 1 || i == 4, isFullScreen: false))
        }
        let switchMap = ["s1": 1, "s2": 2, "s3": 3, "s4": 4]

        // Focus on d2: arrows act on d2, so chain 2 right from desktop 4
        let focusedOnTarget = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 6, spaces: spaces, switchMap: switchMap,
            focusedDisplayID: "d2")
        XCTAssertEqual(
            focusedOnTarget,
            .chainFromCurrent(steps: 2, goRight: true))

        // Focus on d1: arrows would act on d1, so jump to anchor 4 first
        let focusedElsewhere = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 6, spaces: spaces, switchMap: switchMap,
            focusedDisplayID: "d1")
        XCTAssertEqual(
            focusedElsewhere,
            .jumpThenChain(
                anchorSwitchIndex: 4, steps: 2, goRight: true))
    }

    // MARK: - Edge cases

    func testUnreachable_noSpacesMatchTarget() {
        let spaces = makeSpaces(desktops: 3, currentNumber: 1)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 99, spaces: spaces)

        XCTAssertEqual(strategy, .unreachable)
    }

    // MARK: - No arrow shortcuts

    func testNoArrows_chainFromCurrentBecomesUnreachable() {
        // Same setup as testChainFromCurrent_currentIsNearestAnchor:
        // 18 desktops, current=16, target=18. Normally chains from current.
        // Without arrows, no chaining path → but desktop 16 is an anchor,
        // delta=2, needs chain → unreachable.
        let spaces = makeSpaces(desktops: 18, currentNumber: 16)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 18, spaces: spaces,
            hasArrowShortcuts: false)

        XCTAssertEqual(strategy, .unreachable)
    }

    func testNoArrows_directSwitchStillWorks() {
        // 20 desktops, current=20, target=16. Desktop 16 has a shortcut.
        // Without arrows, only directSwitch survives.
        let spaces = makeSpaces(desktops: 20, currentNumber: 20)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 16, spaces: spaces,
            hasArrowShortcuts: false)

        XCTAssertEqual(strategy, .directSwitch(switchIndex: 16))
    }

    func testNoArrows_jumpThenChainBecomesUnreachable() {
        // 20 desktops, current=1, target=18.
        // Normally jumpThenChain from anchor 16. Without arrows, chain fails.
        let spaces = makeSpaces(desktops: 20, currentNumber: 1)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 18, spaces: spaces,
            hasArrowShortcuts: false)

        XCTAssertEqual(strategy, .unreachable)
    }

    func testCrossDisplay_noAnchorOnTargetDisplay_unreachable() {
        // d1 has desktops 1-3 (current=1), d2 has only fullscreen.
        // No anchor on d2 → unreachable.
        let spaces = [
            Space(
                displayID: "d1", spaceID: "s1", spaceName: "",
                spaceNumber: 1, spaceLabel: "1",
                isCurrentSpace: true, isFullScreen: false),
            Space(
                displayID: "d2", spaceID: "f1", spaceName: "",
                spaceNumber: 2, spaceLabel: "F1",
                isCurrentSpace: false, isFullScreen: true),
        ]
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 2, spaces: spaces)

        XCTAssertEqual(strategy, .unreachable)
    }

    func testCrossDisplay_hasAnchor_noArrows_unreachable() {
        // d1 has desktop 1 (current), d2 has desktops 2-4.
        // Anchor on d2 = desktop 2 (only one with enabled shortcut).
        // Target = 4, delta = 2. Without arrows, can't chain → unreachable.
        var spaces: [Space] = []
        spaces.append(Space(
            displayID: "d1", spaceID: "s1", spaceName: "",
            spaceNumber: 1, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false))
        for i in 2...4 {
            spaces.append(Space(
                displayID: "d2", spaceID: "s\(i)", spaceName: "",
                spaceNumber: i, spaceLabel: "\(i - 1)",
                isCurrentSpace: false, isFullScreen: false))
        }
        // Only desktop 2 has an enabled shortcut
        let switchMap = ["s2": 2]
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 4, spaces: spaces,
            switchMap: switchMap,
            hasArrowShortcuts: false)

        XCTAssertEqual(strategy, .unreachable)
    }

    func testFullscreen_jumpThenChain() {
        // 9 desktops + 2 fullscreen (F1=10, F2=11).
        // Current=1, target=11 (F2).
        // From current: 10 steps.
        // From anchor (desktop 9): 2 steps right.
        // arrowsFromCurrent (10) > arrowsFromAnchor (2) + 1
        let spaces = makeSpaces(
            desktops: 9, fullscreen: 2, currentNumber: 1)
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 11, spaces: spaces)

        XCTAssertEqual(
            strategy,
            .jumpThenChain(
                anchorSwitchIndex: 9, steps: 2, goRight: true))
    }

    func testUnreachable_noCurrentSpace() {
        let spaces = [
            Space(
                displayID: "d1", spaceID: "s1", spaceName: "",
                spaceNumber: 1, spaceLabel: "1",
                isCurrentSpace: false, isFullScreen: false)
        ]
        let strategy = SwitchStrategizer.calculateChainingStrategy(
            targetSpaceNumber: 1, spaces: spaces)

        XCTAssertEqual(strategy, .unreachable)
    }
}
