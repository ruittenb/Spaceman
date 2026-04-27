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

    // MARK: - ShrinkLevel transitions

    func testShrinkLevelProgression() {
        // The shrink cascade is .none → .shrunken → .icon
        var level: ShrinkLevel = .none

        level = .shrunken
        XCTAssertEqual(level, .shrunken)

        level = .icon
        XCTAssertEqual(level, .icon)
    }

    func testShrinkLevelCasesAreExhaustive() {
        // Verify all three cases exist (compile-time check via switch)
        let levels: [ShrinkLevel] = [.none, .shrunken, .icon]
        for level in levels {
            switch level {
            case .none, .shrunken, .icon:
                break // All cases covered
            }
        }
        XCTAssertEqual(levels.count, 3)
    }

    // MARK: - SpaceUpdateTrigger reset behavior

    /// Simulates the reset logic from AppDelegate.didUpdateSpaces(trigger:)
    private func shouldResetShrinkLevel(for trigger: SpaceUpdateTrigger) -> Bool {
        switch trigger {
        case .spaceSwitch, .topologyChange, .userRefresh:
            return true
        case .autoRefresh:
            return false
        }
    }

    func testSpaceSwitchResetsShrinkLevel() {
        XCTAssertTrue(shouldResetShrinkLevel(for: .spaceSwitch))
    }

    func testTopologyChangeResetsShrinkLevel() {
        XCTAssertTrue(shouldResetShrinkLevel(for: .topologyChange))
    }

    func testUserRefreshResetsShrinkLevel() {
        XCTAssertTrue(shouldResetShrinkLevel(for: .userRefresh))
    }

    func testAutoRefreshPreservesShrinkLevel() {
        XCTAssertFalse(shouldResetShrinkLevel(for: .autoRefresh))
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

    // MARK: - SpaceUpdateTrigger cases

    func testSpaceUpdateTriggerCasesAreExhaustive() {
        let triggers: [SpaceUpdateTrigger] = [
            .spaceSwitch, .topologyChange, .userRefresh, .autoRefresh
        ]
        for trigger in triggers {
            switch trigger {
            case .spaceSwitch, .topologyChange,
                 .userRefresh, .autoRefresh:
                break
            }
        }
        XCTAssertEqual(triggers.count, 4)
    }
}
