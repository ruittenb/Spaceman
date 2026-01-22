//
//  SpaceNameResolutionTests.swift
//  SpacemanTests
//
//  Tests for space name resolution logic, particularly handling ManagedSpaceID
//  changes after macOS reboots (GitHub issue #17).
//

import XCTest
@testable import Spaceman

final class SpaceNameResolutionTests: XCTestCase {

    // MARK: - Test: Normal case (no ID changes)

    func testResolveSpaceNameInfo_NormalCase_MatchesByID() {
        // Setup: Space with ID "100" at position 1 on display "D1"
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // Query with same ID and position
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    // MARK: - Test: ID changed but position same (reboot scenario)

    func testResolveSpaceNameInfo_IDChanged_MatchesByPosition() {
        // Setup: Space was stored with ID "100" at position 1
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // After reboot, position 1 now has ID "200"
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "200",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    // MARK: - Test: Swapped IDs (the bug from issue #17)

    func testResolveSpaceNameInfo_SwappedIDs_ResolvesCorrectly() {
        // Setup: Two spaces before reboot
        // - ID "100" -> "Work" at position 1
        // - ID "101" -> "Home" at position 2
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            ),
            "101": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "Home",
                spaceByDesktopID: "2",
                displayUUID: "D1",
                positionOnDisplay: 2
            )
        ]

        // After reboot, IDs are swapped:
        // - Position 1 now has ID "101"
        // - Position 2 now has ID "100"

        // Query position 1 with new ID "101"
        let resultPos1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        // Should get "Work" (the name for position 1), NOT "Home" (the old name for ID "101")
        XCTAssertNotNil(resultPos1)
        XCTAssertEqual(resultPos1?.spaceName, "Work", "Position 1 should resolve to 'Work', not the old name for ID 101")

        // Query position 2 with new ID "100"
        let resultPos2 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 2,
            storedNames: storedNames
        )

        // Should get "Home" (the name for position 2), NOT "Work" (the old name for ID "100")
        XCTAssertNotNil(resultPos2)
        XCTAssertEqual(resultPos2?.spaceName, "Home", "Position 2 should resolve to 'Home', not the old name for ID 100")
    }

    // MARK: - Test: Multiple displays with swapped IDs

    func testResolveSpaceNameInfo_MultipleDisplays_SwappedIDs() {
        // Setup: Two displays, each with spaces that have swapped IDs
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Display1-Space1",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            ),
            "101": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "Display1-Space2",
                spaceByDesktopID: "2",
                displayUUID: "D1",
                positionOnDisplay: 2
            ),
            "200": SpaceNameInfo(
                spaceNum: 3,
                spaceName: "Display2-Space1",
                spaceByDesktopID: "1",
                displayUUID: "D2",
                positionOnDisplay: 1
            )
        ]

        // Query D1 position 1 with swapped ID "101"
        let resultD1P1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )
        XCTAssertEqual(resultD1P1?.spaceName, "Display1-Space1")

        // Query D2 position 1 - should not match D1's spaces
        let resultD2P1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D2",
            position: 1,
            storedNames: storedNames
        )
        XCTAssertEqual(resultD2P1?.spaceName, "Display2-Space1")
    }

    // MARK: - Test: No match found

    func testResolveSpaceNameInfo_NoMatch_ReturnsNil() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // Query for a different display
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D2",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNil(result)
    }

    // MARK: - Test: Empty stored names

    func testResolveSpaceNameInfo_EmptyStoredNames_ReturnsNil() {
        let storedNames: [String: SpaceNameInfo] = [:]

        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNil(result)
    }

    // MARK: - Test: Stored name without position info (legacy data)

    func testResolveSpaceNameInfo_LegacyDataWithoutPosition_ReturnsNil() {
        // Legacy data might not have displayUUID or positionOnDisplay
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "LegacySpace",
                spaceByDesktopID: "1"
            )
        ]

        // ID matches but position can't be verified (nil != 1)
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNil(result)
    }

    // MARK: - Test: findSpaceByPosition

    func testFindSpaceByPosition_FindsCorrectSpace() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "First",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            ),
            "101": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "Second",
                spaceByDesktopID: "2",
                displayUUID: "D1",
                positionOnDisplay: 2
            )
        ]

        let result = SpaceObserver.findSpaceByPosition(
            in: storedNames,
            displayID: "D1",
            position: 2
        )

        XCTAssertEqual(result?.spaceName, "Second")
    }

    func testFindSpaceByPosition_ReturnsNilWhenNotFound() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "First",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        let result = SpaceObserver.findSpaceByPosition(
            in: storedNames,
            displayID: "D1",
            position: 5
        )

        XCTAssertNil(result)
    }

    // MARK: - Test: Color preservation through ID swap

    func testResolveSpaceNameInfo_PreservesColorHex() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1,
                currentDisplayIndex: 1,
                currentSpaceNumber: 1,
                colorHex: "FF5733"
            )
        ]

        // Query with new ID after reboot
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.colorHex, "FF5733")
    }
}
