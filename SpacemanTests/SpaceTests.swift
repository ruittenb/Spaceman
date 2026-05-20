//
//  SpaceTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 13/10/2025.
//

import XCTest
@testable import Spaceman

final class SpaceTests: XCTestCase {

    // MARK: - buildSwitchIndexMap tests

    private func makeSpace(id: String, fullScreen: Bool = false) -> Space {
        Space(displayID: "d", spaceID: id, spaceName: "", spaceNumber: 0,
              spaceLabel: "0", isCurrentSpace: false, isFullScreen: fullScreen)
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
        // Fullscreen spaces are not in the map
        XCTAssertEqual(map, ["s1": 1, "s2": 2])
    }

    func testBuildSwitchIndexMap_FullscreenBetweenDesktops() {
        // [D, F, D, D] → desktops 1,2,3 (not 1,3,4); fullscreen omitted
        let spaces = [
            makeSpace(id: "d1"),
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "d2"),
            makeSpace(id: "d3"),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertEqual(map, ["d1": 1, "d2": 2, "d3": 3])
    }

    func testBuildSwitchIndexMap_MultipleFullscreen() {
        let spaces = [
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "f2", fullScreen: true),
            makeSpace(id: "f3", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertTrue(map.isEmpty)
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

    // MARK: - buildSwitchIndexMap: fullscreen behavior

    func testBuildSwitchIndexMap_fullscreenNotInMap() {
        let spaces = [
            makeSpace(id: "d1"),
            makeSpace(id: "f1", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertNil(map["f1"], "Fullscreen spaces must not be in the switch map")
        XCTAssertEqual(map, ["d1": 1])
    }

    func testBuildSwitchIndexMap_multipleFullscreenNotInMap() {
        let spaces = [
            makeSpace(id: "d1"),
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "f2", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertNil(map["f1"])
        XCTAssertNil(map["f2"])
        XCTAssertEqual(map, ["d1": 1])
    }

    func testBuildSwitchIndexMap_onlyFullscreen() {
        let spaces = [
            makeSpace(id: "f1", fullScreen: true),
            makeSpace(id: "f2", fullScreen: true),
            makeSpace(id: "f3", fullScreen: true),
        ]
        let map = Space.buildSwitchIndexMap(for: spaces)
        XCTAssertTrue(map.isEmpty)
    }

    // MARK: - canSwitch

    private func makeSpaceWithNumber(
        id: String, number: Int, fullScreen: Bool = false, current: Bool = false
    ) -> Space {
        Space(displayID: "d", spaceID: id, spaceName: "", spaceNumber: number,
              spaceLabel: "\(number)", isCurrentSpace: current, isFullScreen: fullScreen)
    }

    func testCanSwitch_regularDesktop() {
        let space = makeSpaceWithNumber(id: "d1", number: 1)
        XCTAssertTrue(Space.canSwitch(space: space, switchTag: 1))
    }

    func testCanSwitch_currentSpace_alwaysFalse() {
        let space = makeSpaceWithNumber(id: "d1", number: 1, current: true)
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: 1))
    }

    func testCanSwitch_fullscreen_switchable() {
        let current = makeSpaceWithNumber(id: "d1", number: 1, current: true)
        let space = makeSpaceWithNumber(id: "f1", number: 2, fullScreen: true)
        let spaces = [current, space]
        let enabledMap = ["d1": 1]
        XCTAssertTrue(Space.canSwitch(
            space: space, switchTag: nil,
            spaces: spaces, enabledSwitchMap: enabledMap))
    }

    func testCanSwitch_fullscreen_noArrowShortcuts() {
        let current = makeSpaceWithNumber(id: "d1", number: 1, current: true)
        let space = makeSpaceWithNumber(id: "f1", number: 2, fullScreen: true)
        let spaces = [current, space]
        let enabledMap = ["d1": 1]
        // Same setup as above, but without arrow shortcuts → unreachable
        XCTAssertFalse(Space.canSwitch(
            space: space, switchTag: nil,
            spaces: spaces, enabledSwitchMap: enabledMap,
            hasArrowShortcuts: false))
    }

    func testCanSwitch_desktopBeyondMax_noTag() {
        let space = makeSpaceWithNumber(id: "d17", number: 17)
        // Desktop 17+ has no shortcut and is not fullscreen
        XCTAssertFalse(Space.canSwitch(space: space, switchTag: nil))
    }

    // MARK: - canSwitch (gesture modes)

    func testCanSwitch_gestureMode_noFocusedDisplay_returnsTrue() {
        let desktop = makeSpaceWithNumber(id: "d17", number: 17)
        let fullscreen = makeSpaceWithNumber(id: "f2", number: 11, fullScreen: true)
        for mode: SwitchingMode in [.fast, .instant] {
            XCTAssertTrue(Space.canSwitch(
                space: desktop, switchTag: nil, switchingMode: mode))
            XCTAssertTrue(Space.canSwitch(
                space: fullscreen, switchTag: nil, switchingMode: mode))
        }
    }

    func testCanSwitch_gestureMode_currentSpaceStillFalse() {
        let space = makeSpaceWithNumber(id: "d1", number: 1, current: true)
        for mode: SwitchingMode in [.fast, .instant] {
            XCTAssertFalse(Space.canSwitch(
                space: space, switchTag: 1, switchingMode: mode))
        }
    }

    func testCanSwitch_desktopNoShortcut_sameDisplay_reachableViaChaining() {
        // D5: desktop without shortcut, same display, smooth mode.
        // Arrow shortcuts exist → chainFromCurrent → reachable.
        let current = makeSpaceWithNumber(id: "d1", number: 1, current: true)
        let target = makeSpaceWithNumber(id: "d2", number: 2)
        let spaces = [current, target]
        // enabledSwitchMap has d1 but not d2 (d2 has no shortcut)
        XCTAssertTrue(Space.canSwitch(
            space: target, switchTag: nil,
            spaces: spaces, enabledSwitchMap: ["d1": 1],
            hasArrowShortcuts: true))
    }

    func testCanSwitch_desktopNoShortcut_crossDisplay() {
        // D6: desktop without shortcut, cross-display, smooth mode.
        // Anchor on target display + arrows → reachable.
        let current = Space(
            displayID: "d1", spaceID: "s1", spaceName: "",
            spaceNumber: 1, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false)
        let anchor = Space(
            displayID: "d2", spaceID: "s2", spaceName: "",
            spaceNumber: 2, spaceLabel: "1",
            isCurrentSpace: false, isFullScreen: false)
        let target = Space(
            displayID: "d2", spaceID: "s3", spaceName: "",
            spaceNumber: 3, spaceLabel: "2",
            isCurrentSpace: false, isFullScreen: false)
        let spaces = [current, anchor, target]
        // Only anchor (s2) has an enabled shortcut, target (s3) does not
        XCTAssertTrue(Space.canSwitch(
            space: target, switchTag: nil,
            spaces: spaces, enabledSwitchMap: ["s1": 1, "s2": 2],
            hasArrowShortcuts: true))
    }

    func testCanSwitch_gestureMode_sameDisplay() {
        // Gesture mode, target on focused display → reachable.
        let current = Space(
            displayID: "d1", spaceID: "s1", spaceName: "",
            spaceNumber: 1, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false)
        let target = Space(
            displayID: "d1", spaceID: "s2", spaceName: "",
            spaceNumber: 2, spaceLabel: "2",
            isCurrentSpace: false, isFullScreen: false)
        let spaces = [current, target]
        for mode: SwitchingMode in [.fast, .instant] {
            XCTAssertTrue(Space.canSwitch(
                space: target, switchTag: nil, switchingMode: mode,
                spaces: spaces, focusedDisplayID: "d1"))
        }
    }

    func testCanSwitch_gestureMode_crossDisplay_withShortcut() {
        // Gesture mode, cross-display, desktop with shortcut.
        // Falls through to smooth check → shortcut exists → reachable.
        let currentD1 = Space(
            displayID: "d1", spaceID: "s1", spaceName: "",
            spaceNumber: 1, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false)
        let currentD2 = Space(
            displayID: "d2", spaceID: "s2", spaceName: "",
            spaceNumber: 2, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false)
        let target = Space(
            displayID: "d2", spaceID: "s3", spaceName: "",
            spaceNumber: 3, spaceLabel: "2",
            isCurrentSpace: false, isFullScreen: false)
        let spaces = [currentD1, currentD2, target]
        for mode: SwitchingMode in [.fast, .instant] {
            XCTAssertTrue(Space.canSwitch(
                space: target, switchTag: 3, switchingMode: mode,
                spaces: spaces,
                enabledSwitchMap: ["s1": 1, "s2": 2, "s3": 3],
                focusedDisplayID: "d1"))
        }
    }

    func testCanSwitch_gestureMode_crossDisplay_noAnchor() {
        // Current on d1, target fullscreen on d2 with no anchor on d2.
        // Both displays have a current space (realistic multi-display).
        // s2 has no enabled shortcut, so there's no anchor to jump to.
        let currentD1 = Space(
            displayID: "d1", spaceID: "s1", spaceName: "",
            spaceNumber: 1, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false)
        let currentD2 = Space(
            displayID: "d2", spaceID: "s2", spaceName: "",
            spaceNumber: 2, spaceLabel: "1",
            isCurrentSpace: true, isFullScreen: false)
        let target = Space(
            displayID: "d2", spaceID: "f1", spaceName: "",
            spaceNumber: 3, spaceLabel: "F1",
            isCurrentSpace: false, isFullScreen: true)
        let spaces = [currentD1, currentD2, target]
        for mode: SwitchingMode in [.fast, .instant] {
            XCTAssertFalse(Space.canSwitch(
                space: target, switchTag: nil, switchingMode: mode,
                spaces: spaces, enabledSwitchMap: ["s1": 1],
                focusedDisplayID: "d1"))
        }
    }

    // MARK: - switchTag

    func testSwitchTag_regularDesktop() {
        XCTAssertEqual(Space.switchTag(switchMapEntry: 3, spaceNumber: 3), 3)
    }

    func testSwitchTag_fullscreen_usesNegativeSpaceNumber() {
        // Fullscreen has no switchMapEntry, falls through to -(spaceNumber)
        XCTAssertEqual(Space.switchTag(switchMapEntry: nil, spaceNumber: 10), -10)
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
