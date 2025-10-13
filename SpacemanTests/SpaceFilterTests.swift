//
//  SpaceFilterTests.swift
//  SpacemanTests
//
//  Created by Claude Code
//

import XCTest
@testable import Spaceman

final class SpaceFilterTests: XCTestCase {

    var spaceFilter: SpaceFilter!

    override func setUp() {
        super.setUp()
        spaceFilter = SpaceFilter()
    }

    override func tearDown() {
        spaceFilter = nil
        super.tearDown()
    }

    // MARK: - Test Data Helpers

    func createTestSpaces() -> [Space] {
        return [
            // Display 1
            Space(displayID: "display-1", spaceID: "space-1", spaceName: "Dev", spaceNumber: 1, spaceByDesktopID: "1", isCurrentSpace: false, isFullScreen: false),
            Space(displayID: "display-1", spaceID: "space-2", spaceName: "Mail", spaceNumber: 2, spaceByDesktopID: "2", isCurrentSpace: false, isFullScreen: false),
            Space(displayID: "display-1", spaceID: "space-3", spaceName: "Work", spaceNumber: 3, spaceByDesktopID: "3", isCurrentSpace: true, isFullScreen: false),
            Space(displayID: "display-1", spaceID: "space-4", spaceName: "Browse", spaceNumber: 4, spaceByDesktopID: "4", isCurrentSpace: false, isFullScreen: false),
            Space(displayID: "display-1", spaceID: "space-5", spaceName: "Music", spaceNumber: 5, spaceByDesktopID: "5", isCurrentSpace: false, isFullScreen: false),
            // Display 2
            Space(displayID: "display-2", spaceID: "space-6", spaceName: "Extra", spaceNumber: 6, spaceByDesktopID: "1", isCurrentSpace: false, isFullScreen: false),
            Space(displayID: "display-2", spaceID: "space-7", spaceName: "Monitor", spaceNumber: 7, spaceByDesktopID: "2", isCurrentSpace: false, isFullScreen: false),
        ]
    }

    func createTestSpacesWithFullscreen() -> [Space] {
        return [
            Space(displayID: "display-1", spaceID: "space-1", spaceName: "Dev", spaceNumber: 1, spaceByDesktopID: "1", isCurrentSpace: false, isFullScreen: false),
            Space(displayID: "display-1", spaceID: "space-2", spaceName: "Full", spaceNumber: 2, spaceByDesktopID: "2", isCurrentSpace: true, isFullScreen: true),
            Space(displayID: "display-1", spaceID: "space-3", spaceName: "Work", spaceNumber: 3, spaceByDesktopID: "3", isCurrentSpace: false, isFullScreen: false),
        ]
    }

    // MARK: - Filtering Logic Tests

    func testFilterSpaces_AllMode() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.all

        // When mode is .all, all spaces should be returned
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        XCTAssertEqual(filtered.count, 7)
        XCTAssertEqual(filtered, spaces)
    }

    func testFilterSpaces_CurrentOnlyMode() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.currentOnly

        // When mode is .currentOnly, only current spaces should be returned
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered[0].isCurrentSpace)
        XCTAssertEqual(filtered[0].spaceID, "space-3")
    }

    func testFilterSpaces_CurrentOnlyMode_MultipleCurrentSpaces() {
        var spaces = createTestSpaces()
        // Make another space current (simulating multiple displays)
        spaces[5].isCurrentSpace = true

        let mode = VisibleSpacesMode.currentOnly
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.isCurrentSpace })
    }

    func testFilterSpaces_NeighborsMode_Radius1() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.neighbors

        // Current space is index 2 (space-3)
        // With radius 1, should include indices 1, 2, 3 (spaces 2, 3, 4)
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered[0].spaceID, "space-2")
        XCTAssertEqual(filtered[1].spaceID, "space-3")
        XCTAssertEqual(filtered[2].spaceID, "space-4")
    }

    func testFilterSpaces_NeighborsMode_Radius2() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.neighbors

        // Current space is index 2 (space-3)
        // With radius 2, should include indices 0, 1, 2, 3, 4 (all of display 1)
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 2)

        XCTAssertEqual(filtered.count, 5)
        XCTAssertEqual(filtered[0].spaceID, "space-1")
        XCTAssertEqual(filtered[4].spaceID, "space-5")
    }

    func testFilterSpaces_NeighborsMode_EdgeCase_FirstSpace() {
        var spaces = createTestSpaces()
        // Make the first space current
        spaces[0].isCurrentSpace = true
        spaces[2].isCurrentSpace = false

        let mode = VisibleSpacesMode.neighbors
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        // Should include indices 0, 1 (can't go below 0)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].spaceID, "space-1")
        XCTAssertEqual(filtered[1].spaceID, "space-2")
    }

    func testFilterSpaces_NeighborsMode_EdgeCase_LastSpace() {
        var spaces = createTestSpaces()
        // Make the last space on display 1 current
        spaces[2].isCurrentSpace = false
        spaces[4].isCurrentSpace = true

        let mode = VisibleSpacesMode.neighbors
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        // Should include indices 3, 4 (can't go beyond last space of display)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].spaceID, "space-4")
        XCTAssertEqual(filtered[1].spaceID, "space-5")
    }

    func testFilterSpaces_NeighborsMode_MultipleDisplays() {
        var spaces = createTestSpaces()
        // Make a space on display 2 current as well
        spaces[6].isCurrentSpace = true

        let mode = VisibleSpacesMode.neighbors
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        // Should include neighbors from both displays
        // Display 1: spaces 2, 3, 4 (around space 3)
        // Display 2: spaces 6, 7 (around space 7)
        XCTAssertEqual(filtered.count, 5)

        // Check we have spaces from both displays
        let displayIDs = Set(filtered.map { $0.displayID })
        XCTAssertEqual(displayIDs.count, 2)
    }

    func testFilterSpaces_NeighborsMode_EmptyFallback() {
        var spaces = createTestSpaces()
        // Remove all current space markers (edge case during transitions)
        for i in 0..<spaces.count {
            spaces[i].isCurrentSpace = false
        }

        let mode = VisibleSpacesMode.neighbors
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        // Should fallback to current-only (which returns empty when no current spaces)
        XCTAssertEqual(filtered.count, 0)
    }

    func testFilterSpaces_WithFullscreenSpaces() {
        let spaces = createTestSpacesWithFullscreen()
        let mode = VisibleSpacesMode.all

        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 1)

        XCTAssertEqual(filtered.count, 3)
        XCTAssertTrue(filtered[1].isFullScreen)
    }

    func testFilterSpaces_NeighborsMode_Radius0() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.neighbors

        // With radius 0, should only include current space
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 0)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].spaceID, "space-3")
        XCTAssertTrue(filtered[0].isCurrentSpace)
    }

    func testFilterSpaces_NeighborsMode_NegativeRadius() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.neighbors

        // Negative radius should be clamped to 0 (only current space)
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: -5)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].spaceID, "space-3")
    }

    func testFilterSpaces_NeighborsMode_LargeRadius() {
        let spaces = createTestSpaces()
        let mode = VisibleSpacesMode.neighbors

        // Very large radius should include all spaces on the display with current space
        let filtered = spaceFilter.filter(spaces, mode: mode, neighborRadius: 100)

        XCTAssertEqual(filtered.count, 5) // All 5 spaces from display 1
        XCTAssertTrue(filtered.allSatisfy { $0.displayID == "display-1" })
    }
}
