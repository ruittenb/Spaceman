//
//  AutoShrinkTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 27/04/2026.
//
//  Tests for the auto-shrink state machine and ShrinkOverrides.
//

import XCTest
@testable import Spaceman

final class AutoShrinkTests: XCTestCase {

    // MARK: - SpaceUpdateTrigger reset behavior

    func testSpaceSwitchResetsShrinkLevel() {
        XCTAssertTrue(SpaceUpdateTrigger.spaceSwitch.resetsAutoShrink)
    }

    func testTopologyChangeResetsShrinkLevel() {
        XCTAssertTrue(SpaceUpdateTrigger.topologyChange.resetsAutoShrink)
    }

    func testUserRefreshResetsShrinkLevel() {
        XCTAssertTrue(SpaceUpdateTrigger.userRefresh.resetsAutoShrink)
    }

    func testSessionActiveResetsShrinkLevel() {
        XCTAssertTrue(SpaceUpdateTrigger.sessionActive.resetsAutoShrink)
    }

    func testAutoRefreshPreservesShrinkLevel() {
        XCTAssertFalse(SpaceUpdateTrigger.autoRefresh.resetsAutoShrink)
    }

    // MARK: - ShrinkOverrides

    func testShrinkOverridesFields() {
        let overrides = ShrinkOverrides(
            iconSize: .compact,
            displayStyle: .numbers,
            showFullscreenSpaces: false,
            showNavArrows: false,
            showMissionControl: false)

        XCTAssertEqual(overrides.iconSize, .compact)
        XCTAssertEqual(overrides.displayStyle, .numbers)
        XCTAssertFalse(overrides.showFullscreenSpaces)
        XCTAssertFalse(overrides.showNavArrows)
        XCTAssertFalse(overrides.showMissionControl)
    }

    func testShrinkOverridesDoesNotIncludeRowLayout() {
        // ShrinkOverrides intentionally omits rowLayout —
        // row layout is never overridden because two-row mode
        // is more horizontally compact than single-row.
        let mirror = Mirror(reflecting: ShrinkOverrides(
            iconSize: .compact,
            displayStyle: .numbers,
            showFullscreenSpaces: false,
            showNavArrows: false,
            showMissionControl: false))
        let propertyNames = mirror.children.map { $0.label }
        XCTAssertFalse(propertyNames.contains("rowLayout"))
        XCTAssertEqual(propertyNames.count, 5)
    }
}
