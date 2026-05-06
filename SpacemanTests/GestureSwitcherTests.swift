//
//  GestureSwitcherTests.swift
//  SpacemanTests
//
//  Created by René Uittenbogaard on 2026-05-05.
//  Co-author: Claude Code
//

import XCTest
@testable import Spaceman

// MARK: - Mock event poster

final class MockEventPoster: EventPosting {
    struct Call: Equatable {
        let phase: Int64
        let goRight: Bool
        let velocity: Double
    }

    private(set) var calls: [Call] = []

    func postDockSwipe(
        phase: Int64, goRight: Bool, velocity: Double
    ) {
        calls.append(Call(
            phase: phase, goRight: goRight, velocity: velocity))
    }
}

// MARK: - Tests

final class GestureSwitcherTests: XCTestCase {

    private func makeSpace(
        id: String, number: Int, displayID: String = "d1",
        current: Bool = false, fullScreen: Bool = false
    ) -> Space {
        Space(
            displayID: displayID, spaceID: id, spaceName: "",
            spaceNumber: number, spaceByDesktopID: "\(number)",
            isCurrentSpace: current, isFullScreen: fullScreen)
    }

    private func makeSpaces() -> [Space] {
        [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "s3", number: 3),
            makeSpace(id: "s4", number: 4),
            makeSpace(id: "s5", number: 5),
        ]
    }

    // MARK: - calculateSwitch (pure computation)

    func testCalculateSwitch_rightward() {
        let spaces = makeSpaces()
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[3], current: spaces[0],
            spaces: spaces, mode: .instant)
        XCTAssertNotNil(calc)
        XCTAssertEqual(calc?.steps, 3)
        XCTAssertTrue(calc?.goRight == true)
    }

    func testCalculateSwitch_leftward() {
        var spaces = makeSpaces()
        spaces[0] = makeSpace(id: "s1", number: 1)
        spaces[4] = makeSpace(id: "s5", number: 5, current: true)
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[1], current: spaces[4],
            spaces: spaces, mode: .fast)
        XCTAssertNotNil(calc)
        XCTAssertEqual(calc?.steps, 3)
        XCTAssertTrue(calc?.goRight == false)
    }

    func testCalculateSwitch_velocityScalesBySteps() {
        let spaces = makeSpaces()
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[4], current: spaces[0],
            spaces: spaces, mode: .instant)
        XCTAssertEqual(
            calc?.velocity,
            GestureSwitcher.speedInstant * 4)
    }

    func testCalculateSwitch_fastMode_usesSlowSpeed() {
        let spaces = makeSpaces()
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[1], current: spaces[0],
            spaces: spaces, mode: .fast)
        XCTAssertEqual(
            calc?.velocity,
            GestureSwitcher.speedFast * 1)
    }

    func testCalculateSwitch_crossDisplay_returnsNil() {
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
        ]
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[1], current: spaces[0],
            spaces: spaces, mode: .instant)
        XCTAssertNil(calc)
    }

    func testCalculateSwitch_sameSpace_returnsNil() {
        let spaces = makeSpaces()
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[0], current: spaces[0],
            spaces: spaces, mode: .instant)
        XCTAssertNil(calc)
    }

    func testCalculateSwitch_includesFullscreenInSequence() {
        let spaces = [
            makeSpace(id: "s1", number: 1, current: true),
            makeSpace(id: "s2", number: 2),
            makeSpace(id: "f1", number: 3, fullScreen: true),
        ]
        let calc = GestureSwitcher.calculateSwitch(
            target: spaces[2], current: spaces[0],
            spaces: spaces, mode: .instant)
        XCTAssertEqual(calc?.steps, 2)
        XCTAssertTrue(calc?.goRight == true)
    }

    // MARK: - Event posting (orchestration)

    func testSwitchToSpace_postsThreeEventsPerStep() {
        let mock = MockEventPoster()
        let switcher = GestureSwitcher(eventPoster: mock)
        let spaces = makeSpaces()

        _ = switcher.switchToSpace(
            target: spaces[2], current: spaces[0],
            spaces: spaces, mode: .instant)

        // 2 steps × 3 phases = 6 events
        XCTAssertEqual(mock.calls.count, 6)
    }

    func testSwitchToSpace_phasesAreBeganChangedEnded() {
        let mock = MockEventPoster()
        let switcher = GestureSwitcher(eventPoster: mock)
        let spaces = makeSpaces()

        _ = switcher.switchToSpace(
            target: spaces[1], current: spaces[0],
            spaces: spaces, mode: .instant)

        XCTAssertEqual(mock.calls.count, 3)
        XCTAssertEqual(mock.calls[0].phase, 1) // began
        XCTAssertEqual(mock.calls[1].phase, 2) // changed
        XCTAssertEqual(mock.calls[2].phase, 4) // ended
    }

    func testSwitchToSpace_directionIsConsistent() {
        let mock = MockEventPoster()
        let switcher = GestureSwitcher(eventPoster: mock)
        let spaces = makeSpaces()

        _ = switcher.switchToSpace(
            target: spaces[3], current: spaces[0],
            spaces: spaces, mode: .fast)

        XCTAssertTrue(mock.calls.allSatisfy { $0.goRight })
    }

    func testSwitchToSpace_crossDisplay_postsNothing() {
        let mock = MockEventPoster()
        let switcher = GestureSwitcher(eventPoster: mock)
        let spaces = [
            makeSpace(id: "s1", number: 1, displayID: "d1", current: true),
            makeSpace(id: "s2", number: 2, displayID: "d2"),
        ]

        let result = switcher.switchToSpace(
            target: spaces[1], current: spaces[0],
            spaces: spaces, mode: .instant)

        XCTAssertFalse(result)
        XCTAssertTrue(mock.calls.isEmpty)
    }

    func testSwitchToSpace_currentSpace_postsNothing() {
        let mock = MockEventPoster()
        let switcher = GestureSwitcher(eventPoster: mock)
        let spaces = makeSpaces()

        let result = switcher.switchToSpace(
            target: spaces[0], current: spaces[0],
            spaces: spaces, mode: .instant)

        XCTAssertTrue(result)
        XCTAssertTrue(mock.calls.isEmpty)
    }

    func testSwitchRelative_postsThreeEvents() {
        let mock = MockEventPoster()
        let switcher = GestureSwitcher(eventPoster: mock)

        switcher.switchRelative(goRight: true, mode: .fast)

        XCTAssertEqual(mock.calls.count, 3)
        XCTAssertTrue(mock.calls.allSatisfy { $0.goRight })
        XCTAssertEqual(
            mock.calls[0].velocity, GestureSwitcher.speedFast)
    }
}
