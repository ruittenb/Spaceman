//
//  SpaceTests.swift
//  SpacemanTests
//
//  Created by Claude Code
//

import XCTest
@testable import Spaceman

final class SpaceTests: XCTestCase {

    func testSpaceInitialization() {
        let space = Space(
            displayID: "display-1",
            spaceID: "space-1",
            spaceName: "Development",
            spaceNumber: 1,
            spaceByDesktopID: "1",
            isCurrentSpace: true,
            isFullScreen: false
        )

        XCTAssertEqual(space.displayID, "display-1")
        XCTAssertEqual(space.spaceID, "space-1")
        XCTAssertEqual(space.spaceName, "Development")
        XCTAssertEqual(space.spaceNumber, 1)
        XCTAssertEqual(space.spaceByDesktopID, "1")
        XCTAssertTrue(space.isCurrentSpace)
        XCTAssertFalse(space.isFullScreen)
    }

    func testSpaceWithFullscreen() {
        let space = Space(
            displayID: "display-1",
            spaceID: "space-2",
            spaceName: "Fullscreen App",
            spaceNumber: 2,
            spaceByDesktopID: "2",
            isCurrentSpace: false,
            isFullScreen: true
        )

        XCTAssertTrue(space.isFullScreen)
        XCTAssertFalse(space.isCurrentSpace)
    }

    func testMultipleSpaces() {
        let spaces = [
            Space(displayID: "display-1", spaceID: "space-1", spaceName: "First", spaceNumber: 1, spaceByDesktopID: "1", isCurrentSpace: true, isFullScreen: false),
            Space(displayID: "display-1", spaceID: "space-2", spaceName: "Second", spaceNumber: 2, spaceByDesktopID: "2", isCurrentSpace: false, isFullScreen: false),
            Space(displayID: "display-2", spaceID: "space-3", spaceName: "Third", spaceNumber: 3, spaceByDesktopID: "1", isCurrentSpace: false, isFullScreen: false)
        ]

        XCTAssertEqual(spaces.count, 3)
        XCTAssertEqual(spaces.filter { $0.isCurrentSpace }.count, 1)
        XCTAssertEqual(spaces.filter { $0.displayID == "display-1" }.count, 2)
        XCTAssertEqual(spaces.filter { $0.displayID == "display-2" }.count, 1)
    }
}
