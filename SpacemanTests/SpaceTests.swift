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

    // MARK: - buildSwitchIndexMap tests

    private func makeSpace(id: String, fullScreen: Bool = false) -> Space {
        Space(displayID: "d", spaceID: id, spaceName: "", spaceNumber: 0,
              spaceByDesktopID: "0", isCurrentSpace: false, isFullScreen: fullScreen)
    }

    func testBuildSwitchIndexMap_NoFullscreen() {
        let spaces = (1...3).map { makeSpace(id: "s\($0)") }
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map, ["s1": 1, "s2": 2, "s3": 3])
    }

    func testBuildSwitchIndexMap_FullscreenAtEnd() {
        let spaces = [
            makeSpace(id: "s1"),
            makeSpace(id: "s2"),
            makeSpace(id: "f1", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map, ["s1": 1, "s2": 2, "f1": -1])
    }

    func testBuildSwitchIndexMap_FullscreenBetweenDesktops() {
        // [D, F, D, D] → desktops 1,2,3 (not 1,3,4); fullscreen -1
        let spaces = [
            makeSpace(id: "d1"),
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "d2"),
            makeSpace(id: "d3"),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map, ["d1": 1, "f1": -1, "d2": 2, "d3": 3])
    }

    func testBuildSwitchIndexMap_MultipleFullscreen() {
        let spaces = [
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "f2", fullScreen: true),
            makeSpace(id: "f3", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map, ["f1": -1, "f2": -2, "f3": -3])
    }

    func testBuildSwitchIndexMap_MoreThan10Desktops() {
        let spaces = (1...11).map { makeSpace(id: "s\($0)") }
        let map = Space.buildSwitchIndexMap(for: spaces)
        // First 10 are mapped, 11th is absent
        for i in 1...10 {
            XCTAssertEqual(map["s\(i)"], i)
        }
        XCTAssertNil(map["s11"])
        XCTAssertEqual(map.count, 10)
    }

    func testBuildSwitchIndexMap_Empty() {
        let map = Space.buildSwitchIndexMap(for: [])
        XCTAssertTrue(map.isEmpty)
    }
}
