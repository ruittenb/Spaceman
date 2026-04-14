//
//  SpaceTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 13/10/2025.
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
        // First fullscreen space mapped to -1 (minus key shortcut)
        XCTAssertEqual(map, ["s1": 1, "s2": 2, "f1": -1])
    }

    func testBuildSwitchIndexMap_FullscreenBetweenDesktops() {
        // [D, F, D, D] → desktops 1,2,3 (not 1,3,4); first fullscreen → -1
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
        // Only first fullscreen is mapped
        XCTAssertEqual(map, ["f1": -1])
    }

    func testBuildSwitchIndexMap_MoreThanMaxDesktops() {
        let max = Space.maxSwitchableDesktop
        let spaces = (1...max + 1).map { makeSpace(id: "s\($0)") }
        let map = Space.buildSwitchIndexMap(for: spaces)
        for i in 1...max {
            XCTAssertEqual(map["s\(i)"], i)
        }
        XCTAssertNil(map["s\(max + 1)"])
        XCTAssertEqual(map.count, max)
    }

    func testBuildSwitchIndexMap_Empty() {
        let map = Space.buildSwitchIndexMap(for: [])
        XCTAssertTrue(map.isEmpty)
    }

    // MARK: - buildSwitchIndexMap: F1/F2+ fullscreen behavior

    func testBuildSwitchIndexMap_F1HasMinusOne() {
        let spaces = [
            makeSpace(id: "d1"),
            makeSpace(id: "f1", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map["f1"], -1, "F1 must be mapped to -1")
    }

    func testBuildSwitchIndexMap_F2NotInMap() {
        let spaces = [
            makeSpace(id: "d1"),
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "f2", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map["f1"], -1)
        XCTAssertNil(map["f2"], "F2 must not be in the switch map")
    }

    func testBuildSwitchIndexMap_F3NotInMap() {
        let spaces = [
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "f2", fullScreen: true),
            makeSpace(id: "f3", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map["f1"], -1)
        XCTAssertNil(map["f2"])
        XCTAssertNil(map["f3"])
    }

    // MARK: - canSwitch

    private func makeSpaceWithNumber(
        id: String, number: Int, fullScreen: Bool = false, current: Bool = false
    ) -> Space {
        Space(displayID: "d", spaceID: id, spaceName: "", spaceNumber: number,
              spaceByDesktopID: "\(number)", isCurrentSpace: current, isFullScreen: fullScreen)
    }

    func testCanSwitch_regularDesktop() {
        let space = makeSpaceWithNumber(id: "d1", number: 1)
        XCTAssertTrue(Space.canSwitch(space: space, switchTag: 1, navigateAnywhere: false))
        XCTAssertTrue(Space.canSwitch(space: space, switchTag: 1, navigateAnywhere: true))
    }

    func testCanSwitch_currentSpace_alwaysFalse() {
        let space = makeSpaceWithNumber(id: "d1", number: 1, current: true)
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: 1, navigateAnywhere: false))
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: 1, navigateAnywhere: true))
    }

    func testCanSwitch_F1_alwaysSwitchable() {
        let space = makeSpaceWithNumber(id: "f1", number: 10, fullScreen: true)
        // F1 has tag -1 in switchMap
        XCTAssertTrue(Space.canSwitch(space: space, switchTag: -1, navigateAnywhere: false))
        XCTAssertTrue(Space.canSwitch(space: space, switchTag: -1, navigateAnywhere: true))
    }

    func testCanSwitch_F2_onlyWithChaining() {
        let space = makeSpaceWithNumber(id: "f2", number: 11, fullScreen: true)
        // F2 has no switchMap entry
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: nil, navigateAnywhere: false))
        XCTAssertTrue(Space.canSwitch(space: space, switchTag: nil, navigateAnywhere: true))
    }

    func testCanSwitch_desktopBeyondMax_noTag() {
        let space = makeSpaceWithNumber(id: "d17", number: 17)
        // Desktop 17+ has no shortcut and is not fullscreen
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: nil, navigateAnywhere: false))
        // With chaining: still false (not fullscreen)
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: nil, navigateAnywhere: false))
    }

    // MARK: - switchTag

    func testSwitchTag_regularDesktop() {
        XCTAssertEqual(Space.switchTag(switchMapEntry: 3, spaceNumber: 3), 3)
    }

    func testSwitchTag_F1_usesNegativeSpaceNumber() {
        // F1 has switchMapEntry -1, which is not > 0, so falls through to -(spaceNumber)
        XCTAssertEqual(Space.switchTag(switchMapEntry: -1, spaceNumber: 10), -10)
    }

    func testSwitchTag_F2_usesNegativeSpaceNumber() {
        XCTAssertEqual(Space.switchTag(switchMapEntry: nil, spaceNumber: 11), -11)
    }

    func testSwitchTag_unswitchableDesktop() {
        XCTAssertEqual(Space.switchTag(switchMapEntry: nil, spaceNumber: 17), -17)
    }

    // MARK: - Navigation index constants

    func testNavigationIndicesAreDistinct() {
        let indices: Set<Int> = [
            Space.unswitchableIndex,
            Space.missionControlIndex,
            Space.previousSpaceIndex,
            Space.nextSpaceIndex
        ]
        XCTAssertEqual(indices.count, 4, "All navigation indices must be unique")
    }

    func testNavigationIndicesDoNotCollideWithSwitchMap() {
        let spaces = (1...Space.maxSwitchableDesktop).map { makeSpace(id: "s\($0)") }
        let map = Space.buildSwitchIndexMap(for: spaces)
        let mapValues = Set(map.values)

        XCTAssertFalse(mapValues.contains(Space.missionControlIndex))
        XCTAssertFalse(mapValues.contains(Space.previousSpaceIndex))
        XCTAssertFalse(mapValues.contains(Space.nextSpaceIndex))
        XCTAssertFalse(mapValues.contains(Space.unswitchableIndex))
    }

    func testNavigationIndicesAreNegative() {
        // Must be negative to avoid colliding with desktop indices
        XCTAssertLessThan(Space.unswitchableIndex, 0)
        XCTAssertLessThan(Space.missionControlIndex, 0)
        XCTAssertLessThan(Space.previousSpaceIndex, 0)
        XCTAssertLessThan(Space.nextSpaceIndex, 0)
    }
}
