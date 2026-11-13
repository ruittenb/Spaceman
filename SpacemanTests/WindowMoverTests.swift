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
        current: Bool = false,
        isFullScreen: Bool = false
    ) -> Space {
        Space(
            displayID: displayID,
            spaceID: id,
            spaceName: "",
            spaceNumber: number,
            spaceLabel: "\(number)",
            isCurrentSpace: current,
            isFullScreen: isFullScreen)
    }

    // MARK: - Adjacent space

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

    func testAdjacentSpaceSkipsFullScreenSpace() {
        let spaces = [
            makeSpace(id: "1", number: 1),
            makeSpace(id: "2", number: 2, isFullScreen: true),
            makeSpace(id: "3", number: 3, current: true),
            makeSpace(id: "4", number: 4, isFullScreen: true),
            makeSpace(id: "5", number: 5),
        ]

        XCTAssertEqual(WindowMover.adjacentSpace(.previous, from: spaces[2], in: spaces)?.spaceID, "1")
        XCTAssertEqual(WindowMover.adjacentSpace(.next, from: spaces[2], in: spaces)?.spaceID, "5")
    }

    func testNoAdjacentSpaceWhenOnlyFullScreenNeighbours() {
        let spaces = [
            makeSpace(id: "1", number: 1, current: true),
            makeSpace(id: "2", number: 2, isFullScreen: true),
        ]

        XCTAssertNil(WindowMover.adjacentSpace(.next, from: spaces[0], in: spaces))
    }

    // MARK: - Move resolution

    func testResolveMoveToNextSpace() {
        let spaces = [
            makeSpace(id: "11", number: 1, current: true),
            makeSpace(id: "12", number: 2),
        ]

        XCTAssertEqual(
            WindowMover.resolveMove(.next, windowSpaceIDs: [11], spaces: spaces),
            .move(source: spaces[0], target: spaces[1]))
    }

    func testResolveMoveStaysOnWindowsOwnDisplay() {
        let spaces = [
            makeSpace(id: "11", number: 1, current: true),
            makeSpace(id: "12", number: 2),
            makeSpace(id: "21", number: 3, displayID: "display-2", current: true),
            makeSpace(id: "22", number: 4, displayID: "display-2"),
        ]

        XCTAssertEqual(
            WindowMover.resolveMove(.next, windowSpaceIDs: [21], spaces: spaces),
            .move(source: spaces[2], target: spaces[3]))
        XCTAssertEqual(
            WindowMover.resolveMove(.previous, windowSpaceIDs: [21], spaces: spaces),
            .atEdge)
    }

    func testResolveMoveRejectsWindowOnMultipleSpaces() {
        let spaces = [
            makeSpace(id: "11", number: 1, current: true),
            makeSpace(id: "12", number: 2),
        ]

        XCTAssertEqual(
            WindowMover.resolveMove(.next, windowSpaceIDs: [11, 12], spaces: spaces),
            .failure(.windowOnMultipleSpaces))
    }

    func testResolveMoveRejectsFullScreenWindow() {
        let spaces = [
            makeSpace(id: "11", number: 1),
            makeSpace(id: "12", number: 2, current: true, isFullScreen: true),
            makeSpace(id: "13", number: 3),
        ]

        XCTAssertEqual(
            WindowMover.resolveMove(.next, windowSpaceIDs: [12], spaces: spaces),
            .failure(.fullScreenWindow))
    }

    func testResolveMoveRejectsUnknownSpace() {
        let spaces = [makeSpace(id: "11", number: 1, current: true)]

        XCTAssertEqual(
            WindowMover.resolveMove(.next, windowSpaceIDs: [99], spaces: spaces),
            .failure(.noFocusedWindow))
        XCTAssertEqual(
            WindowMover.resolveMove(.next, windowSpaceIDs: [], spaces: spaces),
            .failure(.noFocusedWindow))
    }

    func testResolveMoveAtEdgeIsNoOp() {
        let spaces = [
            makeSpace(id: "11", number: 1, current: true),
            makeSpace(id: "12", number: 2),
        ]

        XCTAssertEqual(
            WindowMover.resolveMove(.previous, windowSpaceIDs: [11], spaces: spaces),
            .atEdge)
    }
}
