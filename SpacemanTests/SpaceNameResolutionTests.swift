//
//  SpaceNameResolutionTests.swift
//  SpacemanTests
//
//  Tests for space name resolution logic, particularly handling ManagedSpaceID
//  changes after macOS reboots (GitHub issue #17) and user reordering in Mission Control.
//

import XCTest
@testable import Spaceman

final class SpaceNameResolutionTests: XCTestCase {

    // MARK: - Test: idsMatchStored helper

    func testIdsMatchStored_AllIdsMatch_ReturnsTrue() {
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

        let currentIDs: Set<String> = ["100", "101"]
        let result = SpaceObserver.idsMatchStored(
            currentIDs: currentIDs,
            storedNames: storedNames,
            displayID: "D1"
        )

        XCTAssertTrue(result)
    }

    func testIdsMatchStored_IdsDiffer_ReturnsFalse() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // After reboot, new ID "200" instead of "100"
        let currentIDs: Set<String> = ["200"]
        let result = SpaceObserver.idsMatchStored(
            currentIDs: currentIDs,
            storedNames: storedNames,
            displayID: "D1"
        )

        XCTAssertFalse(result)
    }

    func testIdsMatchStored_ExtraSpaceAdded_ReturnsFalse() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // User added a new space
        let currentIDs: Set<String> = ["100", "101"]
        let result = SpaceObserver.idsMatchStored(
            currentIDs: currentIDs,
            storedNames: storedNames,
            displayID: "D1"
        )

        XCTAssertFalse(result)
    }

    func testIdsMatchStored_SpaceDeleted_ReturnsFalse() {
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

        // User deleted a space
        let currentIDs: Set<String> = ["100"]
        let result = SpaceObserver.idsMatchStored(
            currentIDs: currentIDs,
            storedNames: storedNames,
            displayID: "D1"
        )

        XCTAssertFalse(result)
    }

    func testIdsMatchStored_OnlyChecksSpecifiedDisplay() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "D1-Space",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            ),
            "200": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "D2-Space",
                spaceByDesktopID: "1",
                displayUUID: "D2",
                positionOnDisplay: 1
            )
        ]

        // Check D1 only - should match even though D2 IDs differ
        let result = SpaceObserver.idsMatchStored(
            currentIDs: Set(["100"]),
            storedNames: storedNames,
            displayID: "D1"
        )

        XCTAssertTrue(result)
    }

    // MARK: - Test: ID-based matching (usePositionMatching = false)
    // Used when IDs are stable (normal operation, user reordering)

    func testResolveSpaceNameInfo_IDMatching_MatchesByID() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: false
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    func testResolveSpaceNameInfo_IDMatching_UserReorderedSpaces() {
        // User reordering scenario: IDs stay the same but positions change
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

        // User dragged "Home" (ID 101) to position 1
        // The name should follow the space, not stay at the old position
        let resultPos1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",  // Home is now at position 1
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: false
        )

        XCTAssertNotNil(resultPos1)
        XCTAssertEqual(resultPos1?.spaceName, "Home", "Name should follow the space ID, not the position")

        // "Work" (ID 100) is now at position 2
        let resultPos2 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 2,
            storedNames: storedNames,
            usePositionMatching: false
        )

        XCTAssertNotNil(resultPos2)
        XCTAssertEqual(resultPos2?.spaceName, "Work", "Name should follow the space ID, not the position")
    }

    func testResolveSpaceNameInfo_IDMatching_NewSpaceReturnsNil() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // New space with unknown ID
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D1",
            position: 2,
            storedNames: storedNames,
            usePositionMatching: false
        )

        XCTAssertNil(result, "New spaces should return nil so they get default names")
    }

    // MARK: - Test: Position-based matching (usePositionMatching = true)
    // Used when IDs are unreliable (after reboot)

    func testResolveSpaceNameInfo_PositionMatching_MatchesByPosition() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // After reboot, position 1 has new ID "200"
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "200",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: true
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    func testResolveSpaceNameInfo_PositionMatching_SwappedIDs() {
        // Reboot scenario: IDs get swapped
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

        let resultPos1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: true
        )

        XCTAssertNotNil(resultPos1)
        XCTAssertEqual(resultPos1?.spaceName, "Work", "Position 1 should resolve to 'Work' regardless of ID")

        let resultPos2 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 2,
            storedNames: storedNames,
            usePositionMatching: true
        )

        XCTAssertNotNil(resultPos2)
        XCTAssertEqual(resultPos2?.spaceName, "Home", "Position 2 should resolve to 'Home' regardless of ID")
    }

    func testResolveSpaceNameInfo_PositionMatching_DifferentDisplay() {
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
            storedNames: storedNames,
            usePositionMatching: true
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

    // MARK: - Test: Color preservation

    func testResolveSpaceNameInfo_PreservesColorHex_IDMatching() {
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

        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: false
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.colorHex, "FF5733")
    }

    func testResolveSpaceNameInfo_PreservesColorHex_PositionMatching() {
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
            storedNames: storedNames,
            usePositionMatching: true
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.colorHex, "FF5733")
    }

    // MARK: - Test: Empty stored names

    func testResolveSpaceNameInfo_EmptyStoredNames_ReturnsNil() {
        let storedNames: [String: SpaceNameInfo] = [:]

        let resultID = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: false
        )
        XCTAssertNil(resultID)

        let resultPos = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: true
        )
        XCTAssertNil(resultPos)
    }

    // MARK: - Test: Legacy data without position info

    func testResolveSpaceNameInfo_LegacyData_IDMatchingStillWorks() {
        // Legacy data might not have displayUUID or positionOnDisplay
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "LegacySpace",
                spaceByDesktopID: "1"
            )
        ]

        // ID-based matching should still work
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: false
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "LegacySpace")
    }

    func testResolveSpaceNameInfo_LegacyData_PositionMatchingFails() {
        // Legacy data without position info can't be matched by position
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "LegacySpace",
                spaceByDesktopID: "1"
            )
        ]

        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: true
        )

        XCTAssertNil(result, "Position matching requires displayUUID and positionOnDisplay")
    }

    // MARK: - Test: Multiple displays

    func testResolveSpaceNameInfo_MultipleDisplays() {
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

        // Position matching on D1 with swapped ID
        let resultD1P1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: true
        )
        XCTAssertEqual(resultD1P1?.spaceName, "Display1-Space1")

        // Position matching on D2 with unknown ID
        let resultD2P1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D2",
            position: 1,
            storedNames: storedNames,
            usePositionMatching: true
        )
        XCTAssertEqual(resultD2P1?.spaceName, "Display2-Space1")
    }
}
