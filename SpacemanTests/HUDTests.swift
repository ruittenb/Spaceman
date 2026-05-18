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

    func testTargetDisplayID_switchOnSameDisplay() {
        // [1*] [2] [3] → [1] [2] [3*]
        let prev = [
            makeSpace(id: "s1", current: true),
            makeSpace(id: "s2"),
            makeSpace(id: "s3")
        ]
        let curr = [
            makeSpace(id: "s1"),
            makeSpace(id: "s2"),
            makeSpace(id: "s3", current: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: curr, previousSpaces: prev,
            trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "d1")
    }

    func testTargetDisplayID_switchOnSecondDisplay() {
        // Display 1: [1] [2*], Display 2: [4*] [5] [6]
        // → Display 2 switches: [4] [5] [6*]
        let prev = [
            makeSpace(id: "s1", displayID: "d1"),
            makeSpace(id: "s2", displayID: "d1", current: true),
            makeSpace(id: "s4", displayID: "d2", current: true),
            makeSpace(id: "s5", displayID: "d2"),
            makeSpace(id: "s6", displayID: "d2")
        ]
        let curr = [
            makeSpace(id: "s1", displayID: "d1"),
            makeSpace(id: "s2", displayID: "d1", current: true),
            makeSpace(id: "s4", displayID: "d2"),
            makeSpace(id: "s5", displayID: "d2"),
            makeSpace(id: "s6", displayID: "d2", current: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: curr, previousSpaces: prev,
            trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "d2")
    }

    func testTargetDisplayID_crossDisplayClick() {
        // Current display is d1 [2*], user clicks [6] on d2
        // → d2's active space changes from [4] to [6]
        let prev = [
            makeSpace(id: "s1", displayID: "d1"),
            makeSpace(id: "s2", displayID: "d1", current: true),
            makeSpace(id: "s4", displayID: "d2", current: true),
            makeSpace(id: "s5", displayID: "d2"),
            makeSpace(id: "s6", displayID: "d2")
        ]
        let curr = [
            makeSpace(id: "s1", displayID: "d1"),
            makeSpace(id: "s2", displayID: "d1", current: true),
            makeSpace(id: "s4", displayID: "d2"),
            makeSpace(id: "s5", displayID: "d2"),
            makeSpace(id: "s6", displayID: "d2", current: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: curr, previousSpaces: prev,
            trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "d2",
                       "HUD should show on the display where the switch happened")
    }

    func testTargetDisplayID_disabled_returnsNil() {
        let prev = [makeSpace(id: "s1", current: true)]
        let curr = [makeSpace(id: "s1"), makeSpace(id: "s2", current: true)]
        let result = HUDPanel.targetDisplayID(
            spaces: curr, previousSpaces: prev,
            trigger: .spaceSwitch, showHUD: false)
        XCTAssertNil(result)
    }

    func testTargetDisplayID_wrongTrigger_returnsNil() {
        let prev = [makeSpace(id: "s1", current: true)]
        let curr = [makeSpace(id: "s1"), makeSpace(id: "s2", current: true)]
        for trigger: SpaceUpdateTrigger in
            [.topologyChange, .userRefresh, .autoRefresh, .sessionActive] {
            let result = HUDPanel.targetDisplayID(
                spaces: curr, previousSpaces: prev,
                trigger: trigger, showHUD: true)
            XCTAssertNil(result, "Should not show HUD for trigger \(trigger)")
        }
    }

    func testTargetDisplayID_fullscreenSwitch_returnsNil() {
        // Switch to a fullscreen space → no HUD
        let prev = [
            makeSpace(id: "s1", current: true),
            makeSpace(id: "f1", fullScreen: true)
        ]
        let curr = [
            makeSpace(id: "s1"),
            makeSpace(id: "f1", current: true, fullScreen: true)
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: curr, previousSpaces: prev,
            trigger: .spaceSwitch, showHUD: true)
        XCTAssertNil(result)
    }

    func testTargetDisplayID_noChange_returnsNil() {
        // Same state → no HUD (e.g., refresh without actual switch)
        let spaces = [
            makeSpace(id: "s1", current: true),
            makeSpace(id: "s2")
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: spaces, previousSpaces: spaces,
            trigger: .spaceSwitch, showHUD: true)
        XCTAssertNil(result)
    }

    func testTargetDisplayID_emptyPrevious_returnsDisplay() {
        // First update (app launch) — previousSpaces is empty
        let curr = [
            makeSpace(id: "s1", current: true),
            makeSpace(id: "s2")
        ]
        let result = HUDPanel.targetDisplayID(
            spaces: curr, previousSpaces: [],
            trigger: .spaceSwitch, showHUD: true)
        XCTAssertEqual(result, "d1")
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
