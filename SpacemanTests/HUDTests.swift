//
//  HUDTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class HUDTests: XCTestCase {

    private func makeSpace(
        id: String, displayID: String = "d1",
        current: Bool = false, fullScreen: Bool = false
    ) -> Space {
        Space(displayID: displayID, spaceID: id, spaceName: "", spaceNumber: 0,
              spaceLabel: "0", isCurrentSpace: current, isFullScreen: fullScreen)
    }

    // MARK: - targetDisplayID

    func testTargetDisplayID_spaceSwitch_returnsCurrent() {
        let spaces = [
            makeSpace(id: "s1", current: false),
            makeSpace(id: "s2", current: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: spaces, trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "d1")
    }

    func testTargetDisplayID_disabled_returnsNil() {
        let spaces = [makeSpace(id: "s1", current: true)]
        let result = HUDPanel.targetDisplayID(
            spaces: spaces, trigger: .spaceSwitch, showHUD: false)
        XCTAssertNil(result)
    }

    func testTargetDisplayID_wrongTrigger_returnsNil() {
        let spaces = [makeSpace(id: "s1", current: true)]
        for trigger: SpaceUpdateTrigger in
            [.topologyChange, .userRefresh, .autoRefresh, .sessionActive] {
            let result = HUDPanel.targetDisplayID(
                spaces: spaces, trigger: trigger, showHUD: true)
            XCTAssertNil(result, "Should not show HUD for trigger \(trigger)")
        }
    }

    func testTargetDisplayID_fullscreenOnly_returnsNil() {
        let spaces = [
            makeSpace(id: "s1", current: false),
            makeSpace(id: "f1", current: true, fullScreen: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: spaces, trigger: .spaceSwitch, showHUD: true)
        XCTAssertNil(result)
    }

    func testTargetDisplayID_multiDisplay_returnsCorrectDisplay() {
        let spaces = [
            makeSpace(id: "s1", displayID: "laptop", current: false),
            makeSpace(id: "s2", displayID: "external", current: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: spaces, trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "external")
    }

    func testTargetDisplayID_mixedCurrentAndFullscreen_prefersDesktop() {
        // Current fullscreen + current desktop on different displays
        let spaces = [
            makeSpace(id: "f1", displayID: "d1", current: true, fullScreen: true),
            makeSpace(id: "s1", displayID: "d2", current: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: spaces, trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "d2")
    }

    // MARK: - spacesByDisplay

    func testSpacesByDisplay_singleDisplay() {
        let spaces = [
            makeSpace(id: "s1"),
            makeSpace(id: "s2"),
            makeSpace(id: "s3")
        ]
        let groups = HUDPanel.spacesByDisplay(spaces)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 3)
    }

    func testSpacesByDisplay_twoDisplays() {
        let spaces = [
            makeSpace(id: "s1", displayID: "d1"),
            makeSpace(id: "s2", displayID: "d1"),
            makeSpace(id: "s3", displayID: "d2"),
            makeSpace(id: "s4", displayID: "d2")
        ]
        let groups = HUDPanel.spacesByDisplay(spaces)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].count, 2)
        XCTAssertEqual(groups[1].count, 2)
        XCTAssertEqual(groups[0][0].spaceID, "s1")
        XCTAssertEqual(groups[1][0].spaceID, "s3")
    }

    func testSpacesByDisplay_empty() {
        let groups = HUDPanel.spacesByDisplay([])
        XCTAssertEqual(groups.count, 0)
    }

    func testSpacesByDisplay_singleSpace() {
        let groups = HUDPanel.spacesByDisplay([makeSpace(id: "s1")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 1)
    }
}
