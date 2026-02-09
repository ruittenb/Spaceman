//
//  SpaceNameResolutionTests.swift
//  SpacemanTests
//
//  Tests for space name resolution logic, particularly handling ManagedSpaceID
//  changes after macOS reboots (GitHub issue #17), user reorders (#20),
//  and display changes (#22).
//

import XCTest
@testable import Spaceman

final class SpaceNameResolutionTests: XCTestCase {

    // MARK: - Position matching (revalidation mode: reboot / wake / app start)

    func testPositionMatching_NormalCase_MatchesByPosition() {
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
            strategy: .positionOnly
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    func testPositionMatching_IDChanged_MatchesByPosition() {
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
            storedNames: storedNames,
            strategy: .positionOnly
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    func testPositionMatching_SwappedIDs_ResolvesCorrectly() {
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
        // Position 1 now has ID "101", Position 2 now has ID "100"
        let resultPos1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly
        )
        XCTAssertEqual(resultPos1?.spaceName, "Work", "Position 1 should resolve to 'Work' regardless of ID")

        let resultPos2 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 2,
            storedNames: storedNames,
            strategy: .positionOnly
        )
        XCTAssertEqual(resultPos2?.spaceName, "Home", "Position 2 should resolve to 'Home' regardless of ID")
    }

    // MARK: - ID matching (normal operation: user reorders)

    func testIDMatching_NormalCase_MatchesByID() {
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

        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .idOnly
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    func testIDMatching_UserReorder_NameFollowsID() {
        // User drags "Work" (ID 100) from position 1 to position 2
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

        // After reorder: ID 100 is now at position 2, ID 101 at position 1
        let resultPos2 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 2,
            storedNames: storedNames,
            strategy: .idOnly
        )
        XCTAssertEqual(resultPos2?.spaceName, "Work", "Name 'Work' should follow ID 100 to its new position")

        let resultPos1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .idOnly
        )
        XCTAssertEqual(resultPos1?.spaceName, "Home", "Name 'Home' should follow ID 101 to its new position")
    }

    func testIDMatching_UnknownID_ReturnsNil() {
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
            managedSpaceID: "999",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .idOnly
        )

        XCTAssertNil(result, "ID matching should return nil for unknown IDs")
    }

    // MARK: - Disconnected display fallback

    func testPositionMatching_DisconnectedDisplayFallback() {
        // External display was "EXT" but after reconnect macOS assigns new UUID "EXT2"
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Laptop",
                spaceByDesktopID: "1",
                displayUUID: "BUILT-IN",
                positionOnDisplay: 1
            ),
            "200": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "External",
                spaceByDesktopID: "1",
                displayUUID: "EXT",
                positionOnDisplay: 1
            )
        ]

        // Now connected displays are BUILT-IN and EXT2 (new UUID)
        let connectedDisplayIDs: Set<String> = ["BUILT-IN", "EXT2"]

        // Position matching on EXT2 should fall back to disconnected display "EXT"
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "300",
            displayID: "EXT2",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly,
            connectedDisplayIDs: connectedDisplayIDs
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "External", "Should find name from disconnected display by position")
    }

    func testPositionMatching_DisconnectedFallback_DoesNotMatchConnected() {
        // Ensure fallback doesn't pick up entries from connected displays
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Laptop",
                spaceByDesktopID: "1",
                displayUUID: "BUILT-IN",
                positionOnDisplay: 1
            )
        ]

        let connectedDisplayIDs: Set<String> = ["BUILT-IN", "EXT"]

        // EXT has no stored entries, and BUILT-IN position 1 is connected → no fallback match
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "EXT",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly,
            connectedDisplayIDs: connectedDisplayIDs
        )

        XCTAssertNil(result, "Should not match entries from connected displays as disconnected fallback")
    }

    // MARK: - findSpaceByPosition

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

    func testFindSpaceByPosition_WithDisconnectedFallback() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "OldDisplay",
                spaceByDesktopID: "1",
                displayUUID: "OLD-UUID",
                positionOnDisplay: 1
            )
        ]

        let result = SpaceObserver.findSpaceByPosition(
            in: storedNames,
            displayID: "NEW-UUID",
            position: 1,
            connectedDisplayIDs: ["NEW-UUID", "BUILT-IN"]
        )

        XCTAssertEqual(result?.spaceName, "OldDisplay", "Should find entry from disconnected display OLD-UUID")
    }

    // MARK: - mergeSpaceNames

    func testMergeSpaceNames_PreservesDisconnectedDisplayEntries() {
        let updatedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Laptop",
                spaceByDesktopID: "1",
                displayUUID: "BUILT-IN",
                positionOnDisplay: 1
            )
        ]

        let storedNames: [String: SpaceNameInfo] = [
            "50": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Laptop-Old",
                spaceByDesktopID: "1",
                displayUUID: "BUILT-IN",
                positionOnDisplay: 1
            ),
            "200": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "External",
                spaceByDesktopID: "1",
                displayUUID: "EXT",
                positionOnDisplay: 1
            )
        ]

        let merged = SpaceObserver.mergeSpaceNames(
            updatedNames: updatedNames,
            storedNames: storedNames,
            connectedDisplayIDs: ["BUILT-IN"]
        )

        // Should have the updated BUILT-IN entry and the preserved EXT entry
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged["100"]?.spaceName, "Laptop")
        XCTAssertEqual(merged["200"]?.spaceName, "External")
        // Should NOT have the old BUILT-IN entry (it's from a connected display, so updated version wins)
        XCTAssertNil(merged["50"])
    }

    func testMergeSpaceNames_UpdatedNamesOverrideStored() {
        let updatedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Updated",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Old",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        let merged = SpaceObserver.mergeSpaceNames(
            updatedNames: updatedNames,
            storedNames: storedNames,
            connectedDisplayIDs: ["D1"]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged["100"]?.spaceName, "Updated")
    }

    func testMergeSpaceNames_PreservesUserDataEntryWhenIDReassigned() {
        // After lid open, macOS assigns new ID "300" to the external space.
        // The old entry "200" has user data and its position slot is NOT occupied
        // by any updated entry (the position was corrupted to 10 by a rapid update).
        // The merge should preserve "200" as a safety net.
        let updatedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Laptop",
                spaceByDesktopID: "1",
                displayUUID: "LAPTOP",
                positionOnDisplay: 1
            ),
            "300": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1
            )
        ]

        let storedNames: [String: SpaceNameInfo] = [
            "200": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 10,  // corrupted transient position
                colorHex: "FF5733"
            )
        ]

        let merged = SpaceObserver.mergeSpaceNames(
            updatedNames: updatedNames,
            storedNames: storedNames,
            connectedDisplayIDs: ["LAPTOP", "EXTERNAL"]
        )

        // "200" should be preserved: has user data and its posKey "EXTERNAL:10"
        // is not in updatedPositions (which has "EXTERNAL:1").
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged["200"]?.spaceName, "2ND")
        XCTAssertEqual(merged["200"]?.colorHex, "FF5733")
    }

    func testMergeSpaceNames_DropsUserDataEntryWhenPositionMigrated() {
        // After lid open, the entry's data successfully migrated to new ID "300"
        // (position fallback found it). The old entry should NOT be preserved
        // because the new entry occupies the same display+position.
        let updatedNames: [String: SpaceNameInfo] = [
            "300": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1
            )
        ]

        let storedNames: [String: SpaceNameInfo] = [
            "200": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1  // same position as "300" in updatedNames
            )
        ]

        let merged = SpaceObserver.mergeSpaceNames(
            updatedNames: updatedNames,
            storedNames: storedNames,
            connectedDisplayIDs: ["LAPTOP", "EXTERNAL"]
        )

        // "200" should be dropped: its posKey "EXTERNAL:1" IS in updatedPositions
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged["300"]?.spaceName, "2ND")
        XCTAssertNil(merged["200"])
    }

    func testMergeSpaceNames_DropsEmptyEntriesOnConnectedDisplay() {
        // Entries without user data on connected displays should be dropped
        // (they don't have anything worth preserving).
        let updatedNames: [String: SpaceNameInfo] = [
            "300": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        let storedNames: [String: SpaceNameInfo] = [
            "200": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 2  // different position, but no user data
            )
        ]

        let merged = SpaceObserver.mergeSpaceNames(
            updatedNames: updatedNames,
            storedNames: storedNames,
            connectedDisplayIDs: ["D1"]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertNil(merged["200"], "Entries without user data should not be preserved")
    }

    // MARK: - Multiple displays

    func testMultipleDisplays_PositionMatching_SwappedIDs() {
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

        // D1 position 1 with swapped ID "101"
        let resultD1P1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "101",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly
        )
        XCTAssertEqual(resultD1P1?.spaceName, "Display1-Space1")

        // D2 position 1 with unknown ID - should not match D1's spaces
        let resultD2P1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D2",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly
        )
        XCTAssertEqual(resultD2P1?.spaceName, "Display2-Space1")
    }

    // MARK: - Edge cases

    func testPositionMatching_NoMatch_ReturnsNil() {
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
            managedSpaceID: "999",
            displayID: "D2",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly
        )

        XCTAssertNil(result)
    }

    func testResolveSpaceNameInfo_EmptyStoredNames_ReturnsNil() {
        let storedNames: [String: SpaceNameInfo] = [:]

        let resultPosition = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly
        )
        XCTAssertNil(resultPosition)

        let resultID = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .idOnly
        )
        XCTAssertNil(resultID)
    }

    func testPositionMatching_PreservesColorHex() {
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
            managedSpaceID: "999",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.colorHex, "FF5733")
    }

    func testIDMatching_PreservesColorHex() {
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
            strategy: .idOnly
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.colorHex, "FF5733")
    }

    // MARK: - Default parameter backward compatibility

    func testResolveSpaceNameInfo_DefaultIsPositionMatching() {
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            )
        ]

        // Call without strategy parameter — should default to .positionOnly
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D1",
            position: 1,
            storedNames: storedNames
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work")
    }

    // MARK: - ID with position fallback (topology change: lid close/open, mirror↔extend)

    func testIdWithPositionFallback_StableIDs_MatchesByID() {
        // When topology changes but IDs are stable (lid close/open),
        // ID matching should find the correct names.
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "CAL",
                spaceByDesktopID: "1",
                displayUUID: "LAPTOP",
                positionOnDisplay: 1
            ),
            "200": SpaceNameInfo(
                spaceNum: 10,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1
            )
        ]

        // After lid close: ID 100 is on EXTERNAL at pos 1, ID 200 at pos 2.
        // ID matching finds both correctly despite position change.
        let resultPos1 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "EXTERNAL",
            position: 1,
            storedNames: storedNames,
            strategy: .idWithPositionFallback,
            connectedDisplayIDs: ["EXTERNAL"]
        )
        XCTAssertEqual(resultPos1?.spaceName, "CAL", "ID match should find CAL by ID 100")

        let resultPos2 = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "200",
            displayID: "EXTERNAL",
            position: 2,
            storedNames: storedNames,
            strategy: .idWithPositionFallback,
            connectedDisplayIDs: ["EXTERNAL"]
        )
        XCTAssertEqual(resultPos2?.spaceName, "2ND", "ID match should find 2ND by ID 200")
    }

    func testIdWithPositionFallback_NewIDs_FallsBackToPosition() {
        // When topology changes AND IDs are reassigned (e.g., mirror→extend),
        // ID matching fails and position fallback is used.
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Work",
                spaceByDesktopID: "1",
                displayUUID: "MIRROR",
                positionOnDisplay: 1
            )
        ]

        // After mirror→extend: new display UUID "LAPTOP", new ID "300".
        // ID "300" not in store → falls back to position matching.
        // Position 1 on "LAPTOP" not found → disconnected fallback finds "MIRROR"/pos 1.
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "300",
            displayID: "LAPTOP",
            position: 1,
            storedNames: storedNames,
            strategy: .idWithPositionFallback,
            connectedDisplayIDs: ["LAPTOP", "EXTERNAL"]
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "Work", "Position fallback should recover name from disconnected display")
    }

    func testIdWithPositionFallback_MixedStableAndNewIDs() {
        // Some spaces keep their IDs, some get new ones.
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "Laptop1",
                spaceByDesktopID: "1",
                displayUUID: "D1",
                positionOnDisplay: 1
            ),
            "101": SpaceNameInfo(
                spaceNum: 2,
                spaceName: "Laptop2",
                spaceByDesktopID: "2",
                displayUUID: "D1",
                positionOnDisplay: 2
            )
        ]

        // ID 100 is stable, ID 101 was reassigned to 999
        let resultStable = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "D1",
            position: 1,
            storedNames: storedNames,
            strategy: .idWithPositionFallback
        )
        XCTAssertEqual(resultStable?.spaceName, "Laptop1", "Stable ID should match by ID")

        let resultNew = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "999",
            displayID: "D1",
            position: 2,
            storedNames: storedNames,
            strategy: .idWithPositionFallback
        )
        XCTAssertEqual(resultNew?.spaceName, "Laptop2", "New ID should fall back to position matching")
    }

    // MARK: - Position preservation during topology changes (issue #22c)

    func testPositionPreservation_LidCloseOpenRoundTrip() {
        // The full scenario: lid close updates position to 10, then lid open
        // assigns a new ID. If the position was preserved at 1, recovery works.
        // If it was updated to 10, the name is lost.

        // Store after lid close WITH position preservation:
        // "2ND" entry kept its original position 1 (not updated to 10)
        let storedAfterLidClose: [String: SpaceNameInfo] = [
            "200": SpaceNameInfo(
                spaceNum: 10,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1  // preserved, NOT updated to transient pos 10
            )
        ]

        // After lid open: external display has 1 space at pos 1, new ID 300
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "300",
            displayID: "EXTERNAL",
            position: 1,
            storedNames: storedAfterLidClose,
            strategy: .idWithPositionFallback,
            connectedDisplayIDs: ["LAPTOP", "EXTERNAL"]
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.spaceName, "2ND",
            "Position matching finds 2ND at preserved position 1")
    }

    func testPositionNotPreserved_LidCloseOpenRoundTrip_NameLost() {
        // Same scenario, but position was updated to 10 during lid close.
        // After lid open with new ID, position matching can't find it.

        let storedAfterLidClose: [String: SpaceNameInfo] = [
            "200": SpaceNameInfo(
                spaceNum: 10,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 10  // NOT preserved — updated to transient position
            )
        ]

        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "300",
            displayID: "EXTERNAL",
            position: 1,
            storedNames: storedAfterLidClose,
            strategy: .idWithPositionFallback,
            connectedDisplayIDs: ["LAPTOP", "EXTERNAL"]
        )

        XCTAssertNil(result,
            "Position 10 doesn't match position 1 — name is lost without preservation")
    }

    // MARK: - hasUserData

    func testHasUserData_WithName() {
        let info = SpaceNameInfo(spaceNum: 1, spaceName: "Work", spaceByDesktopID: "1")
        XCTAssertTrue(info.hasUserData)
    }

    func testHasUserData_WithColor() {
        var info = SpaceNameInfo(spaceNum: 1, spaceName: "", spaceByDesktopID: "1")
        info.colorHex = "FF5733"
        XCTAssertTrue(info.hasUserData)
    }

    func testHasUserData_Empty() {
        let info = SpaceNameInfo(spaceNum: 1, spaceName: "", spaceByDesktopID: "1")
        XCTAssertFalse(info.hasUserData)
    }

    // MARK: - Topology grace period scenario (issue #22d)

    func testGracePeriod_SecondUpdatePreservesPosition() {
        // Simulates the double-update during lid close:
        // Update 1 uses .idWithPositionFallback (topology detected) → position preserved.
        // Update 2 would normally use .idOnly → position corrupted.
        // With grace period, update 2 also uses .idWithPositionFallback → position preserved.

        // Store before lid close:
        let storeBeforeLidClose: [String: SpaceNameInfo] = [
            "200": SpaceNameInfo(
                spaceNum: 10,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1,
                colorHex: "FF5733"
            )
        ]

        // Update 2 (grace period active): ID 200 is at transient pos 10 on EXTERNAL.
        // Strategy should be .idWithPositionFallback (grace period).
        // ID 200 found in store → position preserved from store.
        let savedInfo = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "200",
            displayID: "EXTERNAL",
            position: 10,
            storedNames: storeBeforeLidClose,
            strategy: .idWithPositionFallback,
            connectedDisplayIDs: ["EXTERNAL"]
        )

        XCTAssertNotNil(savedInfo)
        XCTAssertEqual(savedInfo?.spaceName, "2ND")
        // The resolved info has the STORED position (1), not the transient position (10).
        XCTAssertEqual(savedInfo?.positionOnDisplay, 1)
        XCTAssertEqual(savedInfo?.displayUUID, "EXTERNAL")
    }

    // MARK: - positionOnly bug documentation

    func testPositionOnly_LidClose_MisassignsName() {
        // Documents WHY positionOnly is wrong for topology changes:
        // position matching picks up the external display's stored entry at pos 1,
        // but the space at pos 1 is now actually the laptop's first space.
        let storedNames: [String: SpaceNameInfo] = [
            "100": SpaceNameInfo(
                spaceNum: 1,
                spaceName: "CAL",
                spaceByDesktopID: "1",
                displayUUID: "LAPTOP",
                positionOnDisplay: 1
            ),
            "200": SpaceNameInfo(
                spaceNum: 10,
                spaceName: "2ND",
                spaceByDesktopID: "1",
                displayUUID: "EXTERNAL",
                positionOnDisplay: 1
            )
        ]

        // After lid close: all on EXTERNAL. Pos 1 is ID 100 (was laptop's CAL).
        // positionOnly finds EXTERNAL/pos 1 → "2ND", which is WRONG.
        let result = SpaceObserver.resolveSpaceNameInfo(
            managedSpaceID: "100",
            displayID: "EXTERNAL",
            position: 1,
            storedNames: storedNames,
            strategy: .positionOnly,
            connectedDisplayIDs: ["EXTERNAL"]
        )
        XCTAssertEqual(result?.spaceName, "2ND",
            "positionOnly incorrectly assigns 2ND to pos 1 — this is the bug that idWithPositionFallback fixes")
    }
}
