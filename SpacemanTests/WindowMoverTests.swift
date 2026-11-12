//
//  WindowMoverTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class WindowMoverTests: XCTestCase {
    private func makeSpace(
        id: String,
        number: Int,
        displayID: String = "display-1",
        current: Bool = false
    ) -> Space {
        Space(
            displayID: displayID,
            spaceID: id,
            spaceName: "",
            spaceNumber: number,
            spaceLabel: "\(number)",
            isCurrentSpace: current,
            isFullScreen: false)
    }

    func testMissionControlArrowEventFlagsPreserveFunctionKeyFlag() {
        let flags = ShortcutHelper.eventFlags(
            fromSymbolicHotKeyModifiers: 8_650_752)

        XCTAssertTrue(flags.contains(.maskControl))
        XCTAssertTrue(flags.contains(.maskSecondaryFn))
    }

    func testOnlyITermNeedsActivationDrag() {
        XCTAssertTrue(WindowMover.needsActivationDrag(bundleIdentifier: "com.googlecode.iterm2"))
        XCTAssertTrue(WindowMover.needsActivationDrag(bundleIdentifier: "com.googlecode.iterm2-nightly"))
        XCTAssertFalse(WindowMover.needsActivationDrag(bundleIdentifier: "com.apple.TextEdit"))
        XCTAssertFalse(WindowMover.needsActivationDrag(bundleIdentifier: nil))
    }

    func testAdjacentSpaceExistsWithinCurrentDisplay() {
        let spaces = [
            makeSpace(id: "one", number: 1),
            makeSpace(id: "two", number: 2, current: true),
            makeSpace(id: "three", number: 3),
        ]

        XCTAssertTrue(WindowMover.hasAdjacentSpace(.previous, from: spaces[1], in: spaces))
        XCTAssertTrue(WindowMover.hasAdjacentSpace(.next, from: spaces[1], in: spaces))
    }

    func testNoAdjacentSpaceAtDisplayEdges() {
        let spaces = [
            makeSpace(id: "one", number: 1, current: true),
            makeSpace(id: "two", number: 2),
        ]

        XCTAssertFalse(WindowMover.hasAdjacentSpace(.previous, from: spaces[0], in: spaces))
        XCTAssertFalse(WindowMover.hasAdjacentSpace(.next, from: spaces[1], in: spaces))
    }

    func testAdjacentSpaceCheckDoesNotCrossDisplays() {
        let current = makeSpace(
            id: "external-only",
            number: 3,
            displayID: "display-2",
            current: true)
        let spaces = [
            makeSpace(id: "one", number: 1),
            makeSpace(id: "two", number: 2),
            current,
            makeSpace(id: "four", number: 4),
        ]

        XCTAssertFalse(WindowMover.hasAdjacentSpace(.previous, from: current, in: spaces))
        XCTAssertFalse(WindowMover.hasAdjacentSpace(.next, from: current, in: spaces))
    }
}
