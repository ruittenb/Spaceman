//
//  SpaceObserverIntegrationTests.swift
//  SpacemanTests
//
//  Tests the full SpaceObserver.performSpaceInformationUpdate() flow:
//  strategy selection, grace period, position preservation, and delegate callback.
//

import XCTest
@testable import Spaceman

// MARK: - Test Helpers

private class MockDelegate: SpaceObserverDelegate {
    var receivedSpaces: [Space] = []
    var receivedTrigger: SpaceUpdateTrigger?
    var updateExpectation: XCTestExpectation?

    func didUpdateSpaces(spaces: [Space], trigger: SpaceUpdateTrigger) {
        receivedSpaces = spaces
        receivedTrigger = trigger
        updateExpectation?.fulfill()
    }
}

/// Builds mock display dictionaries matching the format returned by CGSCopyManagedDisplaySpaces.
private func makeDisplay(
    id: String,
    currentSpaceID: Int,
    spaces: [(id: Int, isFullScreen: Bool)] = []
) -> NSDictionary {
    let spaceDicts: [[String: Any]] = spaces.map { space in
        var dict: [String: Any] = ["ManagedSpaceID": space.id]
        if space.isFullScreen {
            dict["TileLayoutManager"] = ["dummy": true]
        }
        return dict
    }
    return [
        "Display Identifier": id,
        "Current Space": ["ManagedSpaceID": currentSpaceID],
        "Spaces": spaceDicts
    ] as NSDictionary
}

private func makeTestStore() -> SpaceNameStore {
    let suiteName = "SpaceObserverIntegrationTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return SpaceNameStore(defaults: defaults)
}

// MARK: - Tests

final class SpaceObserverIntegrationTests: XCTestCase {

    private var observer: SpaceObserver!
    private var delegate: MockDelegate!
    private var nameStore: SpaceNameStore!

    override func setUp() {
        super.setUp()
        nameStore = makeTestStore()
        observer = SpaceObserver(nameStore: nameStore)
        delegate = MockDelegate()
        observer.delegate = delegate
    }

    override func tearDown() {
        observer = nil
        delegate = nil
        nameStore = nil
        super.tearDown()
    }

    /// Helper: run an update and wait for the delegate callback.
    private func runUpdate(trigger: SpaceUpdateTrigger = .userRefresh, timeout: TimeInterval = 2) {
        let exp = expectation(description: "didUpdateSpaces")
        delegate.updateExpectation = exp
        observer.updateSpaceInformation(trigger: trigger)
        wait(for: [exp], timeout: timeout)
    }

    /// Helper: simulate wake by posting the notification SpaceObserver listens on.
    private func simulateWake() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification, object: NSWorkspace.shared)
    }

    // MARK: - Basic Flow

    func testSingleDisplay_delegateReceivesCorrectSpaces() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false),
                (id: 103, isFullScreen: false)
            ])]
        }

        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces.count, 3)
        XCTAssertEqual(delegate.receivedSpaces[0].spaceID, "101")
        XCTAssertEqual(delegate.receivedSpaces[0].isCurrentSpace, true)
        XCTAssertEqual(delegate.receivedSpaces[1].spaceID, "102")
        XCTAssertEqual(delegate.receivedSpaces[1].isCurrentSpace, false)
        XCTAssertEqual(delegate.receivedSpaces[2].spaceID, "103")
        XCTAssertEqual(delegate.receivedSpaces[2].isCurrentSpace, false)
        XCTAssertEqual(delegate.receivedTrigger, .userRefresh)
    }

    func testFullScreenSpace_isMarkedCorrectly() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 201, spaces: [
                (id: 201, isFullScreen: false),
                (id: 202, isFullScreen: true)
            ])]
        }

        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces[0].isFullScreen, false)
        XCTAssertEqual(delegate.receivedSpaces[1].isFullScreen, true)
    }

    func testTriggerIsPassedThrough() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 1, spaces: [(id: 1, isFullScreen: false)])]
        }

        runUpdate(trigger: .spaceSwitch)
        XCTAssertEqual(delegate.receivedTrigger, .spaceSwitch)
    }

    // MARK: - Strategy Selection: First Update (Position Matching)

    /// On first update (_needsPositionRevalidation=true, no prior display IDs),
    /// the strategy is .idWithPositionFallback (not positionOnly) because the display UUID
    /// won't be in storedDisplayIDs, and the "needsRevalidation || inTopologyTransition" branch fires.
    func testFirstUpdate_usesIdWithPositionFallback_matchesByPosition() {
        // Pre-store a name at position 1 on display-A, under a DIFFERENT space ID
        nameStore.save(["999": SpaceNameInfo(
            spaceNum: 1, spaceName: "HOME", spaceByDesktopID: "1",
            displayUUID: "display-A", positionOnDisplay: 1)])

        observer.displaySpacesProvider = {
            // Space ID 101 is at position 1 on display-A
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        runUpdate()

        // Should have resolved name "HOME" via position fallback
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "HOME")
    }

    // MARK: - Strategy Selection: Normal Operation (ID Matching)

    /// After the first update establishes display IDs, subsequent updates
    /// with no topology change and no wake use .idOnly.
    func testNormalUpdate_usesIdOnly() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // First update — clears revalidation flag, sets _lastKnownDisplayIDs
        runUpdate()

        // Store a name under ID "101"
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "WORK", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
        }

        // Second update — same topology, no wake → .idOnly
        runUpdate(trigger: .spaceSwitch)

        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "WORK")
    }

    /// With .idOnly, names follow their space ID even if positions change.
    func testNormalUpdate_idOnly_tracksReorder() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // First update
        runUpdate()

        // Store names under their IDs
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "FIRST", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "SECOND", spaceByDesktopID: "2",
                displayUUID: "display-A", positionOnDisplay: 2)
        }

        // Now reorder: space 102 comes before 101
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 102, isFullScreen: false),
                (id: 101, isFullScreen: false)
            ])]
        }

        runUpdate(trigger: .spaceSwitch)

        // Names should follow IDs, not positions
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "SECOND")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "FIRST")
    }

    // MARK: - Strategy Selection: Wake (Position Matching)

    /// After wake with unchanged topology, .positionOnly is used.
    /// This handles ID swaps: if macOS gives space-at-pos-1 the ID that pos-2 used to have.
    func testWake_sameTopology_usesPositionMatching() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // First update — establishes topology
        runUpdate()

        // Store names at known positions
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "POS1", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "POS2", spaceByDesktopID: "2",
                displayUUID: "display-A", positionOnDisplay: 2)
        }

        // Simulate wake
        simulateWake()

        // After wake, macOS swapped IDs: pos 1 now has ID 102, pos 2 has ID 101
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 102, spaces: [
                (id: 102, isFullScreen: false),
                (id: 101, isFullScreen: false)
            ])]
        }

        runUpdate(trigger: .spaceSwitch)

        // Position matching: pos 1 → "POS1", pos 2 → "POS2" (ignores swapped IDs)
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "POS1")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "POS2")
    }

    // MARK: - Strategy Selection: Topology Change (ID-first)

    /// When display topology changes, .idWithPositionFallback is used.
    func testTopologyChange_usesIdWithPositionFallback() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // First update — establishes display-A as known
        runUpdate()

        // Store names
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "ALPHA", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "BETA", spaceByDesktopID: "2",
                displayUUID: "display-A", positionOnDisplay: 2)
        }

        // Topology change: display-B appears, display-A still there
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false),
                    (id: 102, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        runUpdate(trigger: .topologyChange)

        // ID matching should find "ALPHA" and "BETA" by their IDs
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "ALPHA")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "BETA")
        // New space 201 has no stored name
        XCTAssertEqual(delegate.receivedSpaces[2].spaceName, "---")
    }

    // MARK: - Strategy Selection: Wake + Topology Change (Topology Wins)

    /// When both wake and topology change happen (e.g., sleep→mirror→wake),
    /// topology wins: .idWithPositionFallback is used (not .positionOnly).
    /// This is issue #29.
    func testWakePlusTopologyChange_topologyWins() {
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        // First update — establishes topology as {display-A, display-B}
        runUpdate()

        // Store names under their IDs
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "LAPTOP", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["201"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "EXTERN", spaceByDesktopID: "2",
                displayUUID: "display-B", positionOnDisplay: 1)
        }

        // Simulate wake
        simulateWake()

        // Topology also changed: display-B is gone, display-C appeared
        // Space 201 is now on display-C (same ID, different display)
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false)
                ]),
                makeDisplay(id: "display-C", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        runUpdate(trigger: .spaceSwitch)

        // Topology wins → .idWithPositionFallback → ID matching finds both
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "LAPTOP")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "EXTERN")
    }

    // MARK: - Grace Period

    /// After a topology change, the grace period keeps .idWithPositionFallback
    /// active for several follow-up updates.
    func testGracePeriod_preventsIdOnlyAfterTopologyChange() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // First update — establishes display-A
        runUpdate()

        // Topology change: display-B replaces display-A
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-B", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // Store names under IDs (these should survive topology-aware matching)
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "ONE", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "TWO", spaceByDesktopID: "2",
                displayUUID: "display-A", positionOnDisplay: 2)
        }

        // This update detects topology change → grace period starts
        runUpdate(trigger: .topologyChange)
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "ONE")

        // Immediately following updates should still use .idWithPositionFallback
        // (grace period prevents .idOnly which would fail for the stored entries
        //  that still reference display-A)
        runUpdate(trigger: .spaceSwitch)
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "ONE")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "TWO")
    }

    /// Grace period counts down to zero, after which .idOnly resumes.
    func testGracePeriod_expiresAfterEnoughUpdates() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        // Establish topology
        runUpdate()

        // Topology change
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-B", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }
        runUpdate(trigger: .topologyChange) // sets grace period = 5

        // Run 5 more updates to exhaust grace period (5 → 4 → 3 → 2 → 1 → 0)
        for _ in 0..<5 {
            runUpdate(trigger: .spaceSwitch)
        }

        // Now store a name under the correct display-B
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "SETTLED", spaceByDesktopID: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        }

        // This update should use .idOnly (grace period expired, no wake)
        runUpdate(trigger: .spaceSwitch)
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "SETTLED")
    }

    // MARK: - Position Preservation During Topology Change

    /// During topology changes with ID matching, stored position/display are preserved.
    /// This ensures position-based recovery works if IDs change on the reverse transition.
    func testTopologyChange_preservesStoredPosition() {
        // Setup: laptop display-A with spaces 101,102 and external display-B with space 201
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false),
                    (id: 102, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        // First update
        runUpdate()

        // Store name for external display space
        nameStore.update { stored in
            stored["201"] = SpaceNameInfo(
                spaceNum: 3, spaceName: "EXT", spaceByDesktopID: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        }

        // Lid close: display-B disappears, space 201 migrates to display-A at position 3
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false),
                (id: 201, isFullScreen: false)
            ])]
        }

        runUpdate(trigger: .topologyChange)

        // Verify the stored entry for "201" still has display-B/pos 1, NOT display-A/pos 3
        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["201"]?.displayUUID, "display-B",
                       "Position preservation: displayUUID should not be overwritten during topology change")
        XCTAssertEqual(stored["201"]?.positionOnDisplay, 1,
                       "Position preservation: positionOnDisplay should not be overwritten during topology change")
    }

    /// Full lid close/open round trip: position preservation enables recovery
    /// when macOS assigns a new ID on lid reopen.
    func testLidCloseOpen_positionRecovery() {
        // Initial: display-A (laptop) + display-B (external)
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }
        runUpdate()

        // Store "EXT" on display-B, pos 1
        nameStore.update { stored in
            stored["201"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "EXT", spaceByDesktopID: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        }

        // Lid close: display-B gone, space 201 migrates to display-A
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 201, isFullScreen: false)
            ])]
        }
        runUpdate(trigger: .topologyChange)

        // Verify position was preserved (display-B/pos 1, not display-A/pos 2)
        var stored = nameStore.loadAll()
        XCTAssertEqual(stored["201"]?.displayUUID, "display-B")
        XCTAssertEqual(stored["201"]?.positionOnDisplay, 1)

        // Lid reopen: display-B returns, but macOS assigns a NEW ID (301) to the external space
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 301, spaces: [
                    (id: 301, isFullScreen: false)
                ])
            ]
        }
        runUpdate(trigger: .topologyChange)

        // Space 301 should recover "EXT" via position fallback (display-B, pos 1)
        XCTAssertEqual(delegate.receivedSpaces.count, 2)
        let extSpace = delegate.receivedSpaces.first { $0.displayID == "display-B" }
        XCTAssertEqual(extSpace?.spaceName, "EXT",
                       "Position fallback should recover name after ID reassignment")

        // The store should now have "EXT" under key "301"
        stored = nameStore.loadAll()
        XCTAssertEqual(stored["301"]?.spaceName, "EXT")
    }

    // MARK: - Merge: Disconnected Display Preservation

    /// Names for disconnected displays are preserved in the store.
    func testMerge_preservesDisconnectedDisplayNames() {
        // Start with two displays
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }
        runUpdate()

        // Store names for both displays
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "LAPTOP", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["201"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "MONITOR", spaceByDesktopID: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        }

        // Display-B disconnects
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }
        runUpdate(trigger: .topologyChange)

        // display-B's entry should still be in the store
        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["201"]?.spaceName, "MONITOR",
                       "Disconnected display names must be preserved in the store")
        XCTAssertEqual(stored["201"]?.displayUUID, "display-B")
    }

    // MARK: - Name Store: Only Saves When Changed

    /// If the resolved data matches what's already stored, no save occurs.
    func testNoSave_whenDataUnchanged() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        // First update — stores initial data
        runUpdate()

        let storeAfterFirst = nameStore.loadAll()

        // Second update with same data
        runUpdate(trigger: .spaceSwitch)

        let storeAfterSecond = nameStore.loadAll()

        // Data should be identical (store was not modified unnecessarily)
        XCTAssertEqual(storeAfterFirst, storeAfterSecond)
    }

    // MARK: - Multi-Display Space Numbering

    func testMultiDisplay_spaceNumberingIsSequential() {
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false),
                    (id: 102, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces[0].spaceNumber, 1)
        XCTAssertEqual(delegate.receivedSpaces[1].spaceNumber, 2)
        XCTAssertEqual(delegate.receivedSpaces[2].spaceNumber, 3)
    }

    // MARK: - Empty/Nil Display Data

    func testNilDisplayData_noDelegate() {
        observer.displaySpacesProvider = { nil }

        // Should not crash, and delegate should not be called
        let exp = expectation(description: "should not fire")
        exp.isInverted = true
        delegate.updateExpectation = exp
        observer.updateSpaceInformation(trigger: .userRefresh)
        wait(for: [exp], timeout: 0.5)
    }

    func testEmptyDisplayArray_delegateReceivesEmptySpaces() {
        observer.displaySpacesProvider = { [] }

        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces.count, 0)
    }

    // MARK: - Color Preservation

    func testColorHex_isPassedToSpace() {
        nameStore.save(["101": SpaceNameInfo(
            spaceNum: 1, spaceName: "RED", spaceByDesktopID: "1",
            displayUUID: "display-A", positionOnDisplay: 1,
            currentDisplayIndex: nil, currentSpaceNumber: nil,
            colorHex: "FF0000")])

        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces[0].colorHex, "FF0000")
    }

    // MARK: - Restart Numbering By Display

    func testRestartNumberingByDisplay() {
        UserDefaults.standard.set(true, forKey: "restartNumberingByDisplay")
        defer { UserDefaults.standard.removeObject(forKey: "restartNumberingByDisplay") }

        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false),
                    (id: 102, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        runUpdate()

        // With restart numbering, each display starts from "1"
        XCTAssertEqual(delegate.receivedSpaces[0].spaceByDesktopID, "1")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceByDesktopID, "2")
        XCTAssertEqual(delegate.receivedSpaces[2].spaceByDesktopID, "1",
                       "Second display should restart numbering at 1")
    }

    // MARK: - Fullscreen Space Labeling

    func testFullScreenSpace_getsF_prefix() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: true),
                (id: 103, isFullScreen: true)
            ])]
        }

        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces[0].spaceByDesktopID, "1")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceByDesktopID, "F1")
        XCTAssertEqual(delegate.receivedSpaces[2].spaceByDesktopID, "F2")
    }

    // MARK: - Resolve Space Name Fallbacks

    func testResolveSpaceName_noStoredName_showsDashes() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        // No pre-stored name → should show "---"
        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "---")
    }

    func testResolveSpaceName_fullscreen_noStoredName_showsFULL() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: true)
            ])]
        }

        // No stored name and no PID in the space dict → should show "FULL"
        runUpdate()

        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "FULL")
    }

    // MARK: - Current Display Index

    func testCurrentDisplayIndex_assignedPerDisplay() {
        observer.displaySpacesProvider = {
            [
                makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                    (id: 101, isFullScreen: false),
                    (id: 102, isFullScreen: false)
                ]),
                makeDisplay(id: "display-B", currentSpaceID: 201, spaces: [
                    (id: 201, isFullScreen: false)
                ])
            ]
        }

        runUpdate()

        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["101"]?.currentDisplayIndex, 1)
        XCTAssertEqual(stored["102"]?.currentDisplayIndex, 1)
        XCTAssertEqual(stored["201"]?.currentDisplayIndex, 2)
    }
}
