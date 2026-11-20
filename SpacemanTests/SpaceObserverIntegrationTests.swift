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

// MARK: - Tests

final class SpaceObserverIntegrationTests: XCTestCase {

    private var observer: SpaceObserver!
    private var delegate: MockDelegate!
    private var nameStore: SpaceNameStore!
    private var suiteName: String!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SpaceObserverIntegrationTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
        nameStore = SpaceNameStore(defaults: testDefaults)
        observer = SpaceObserver(nameStore: nameStore)
        // Only the test may trigger updates: detach from real system and app notifications.
        // The wake notification stays: simulateWake() relies on it.
        NotificationCenter.default.removeObserver(observer!)
        DistributedNotificationCenter.default().removeObserver(observer!)
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.removeObserver(observer!, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspaceCenter.removeObserver(observer!, name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        delegate = MockDelegate()
        observer.delegate = delegate
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        observer = nil
        delegate = nil
        nameStore = nil
        testDefaults = nil
        super.tearDown()
    }

    /// Helper: run an update and wait for the delegate callback.
    /// The observer also listens to real system notifications (space switch, screen change, unlock),
    /// so a stray update may call the delegate an extra time. Tolerate that instead of failing.
    private func runUpdate(trigger: SpaceUpdateTrigger = .userRefresh, timeout: TimeInterval = 2) {
        let exp = expectation(description: "didUpdateSpaces")
        exp.assertForOverFulfill = false
        delegate.updateExpectation = exp
        observer.updateSpaceInformation(trigger: trigger)
        wait(for: [exp], timeout: timeout)
        delegate.updateExpectation = nil
    }

    /// Helper: set a value in UserDefaults.standard (the host app's real preferences) while `body`
    /// runs, then restore the previous value, or remove the key if it was not set before.
    private func withStandardDefault(_ key: String, setTo value: Any, _ body: () -> Void) {
        let standardDefaults = UserDefaults.standard
        let previousValue = standardDefaults.object(forKey: key)
        standardDefaults.set(value, forKey: key)
        defer {
            if let previousValue {
                standardDefaults.set(previousValue, forKey: key)
            } else {
                standardDefaults.removeObject(forKey: key)
            }
        }
        body()
    }

    /// Helper: laptop display-A (spaces 101, 102) and external display-B (space 201, named "EXT"
    /// at display-B/pos 1). Then the lid closes: display-B disappears and space 201 migrates to
    /// display-A at position 3. Returns after the topology-change update.
    private func runLidCloseScenario() {
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

        nameStore.update { stored in
            stored["201"] = SpaceNameInfo(
                spaceNum: 3, spaceName: "EXT", spaceLabel: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        }

        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false),
                (id: 201, isFullScreen: false)
            ])]
        }
        runUpdate(trigger: .topologyChange)
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

    /// On first update (_needsPositionRevalidation=true, no prior display IDs), no topology change
    /// is detected (_lastKnownDisplayIDs is still empty), so the strategy is .positionOnly.
    func testFirstUpdate_usesPositionOnly_matchesByPosition() {
        // Pre-store a name at position 1 on display-A under a DIFFERENT space ID, and a stale
        // entry under the current ID at another position. ID-first matching would pick "STALE".
        nameStore.save([
            "999": SpaceNameInfo(
                spaceNum: 1, spaceName: "HOME", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1),
            "101": SpaceNameInfo(
                spaceNum: 2, spaceName: "STALE", spaceLabel: "2",
                displayUUID: "display-A", positionOnDisplay: 2)
        ])

        observer.displaySpacesProvider = {
            // Space ID 101 is at position 1 on display-A
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        runUpdate()

        // Should have resolved name "HOME" by position, ignoring the stored entry for ID 101
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

        // Store names whose positions differ from the current ones:
        // .positionOnly would give pos 1 "OTHER", and .idWithPositionFallback would keep
        // the stored position 2 for ID 101 instead of updating it.
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "WORK", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 2)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "OTHER", spaceLabel: "2",
                displayUUID: "display-A", positionOnDisplay: 1)
        }

        // Second update — same topology, no wake → .idOnly
        runUpdate(trigger: .spaceSwitch)

        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "WORK")
        XCTAssertEqual(nameStore.loadAll()["101"]?.positionOnDisplay, 1,
                       ".idOnly updates the stored position to the current one")
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
                spaceNum: 1, spaceName: "FIRST", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "SECOND", spaceLabel: "2",
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
                spaceNum: 1, spaceName: "POS1", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "POS2", spaceLabel: "2",
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

        // Store names. The stored positions of ALPHA and BETA deliberately differ from the current
        // ones, so .positionOnly would swap them. "OLDEXT" belongs to a display that is no longer
        // connected; only the position fallback (not .idOnly) can recover it.
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "ALPHA", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 2)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "BETA", spaceLabel: "2",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["900"] = SpaceNameInfo(
                spaceNum: 3, spaceName: "OLDEXT", spaceLabel: "1",
                displayUUID: "display-X", positionOnDisplay: 1)
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
        let spacesByID = Dictionary(uniqueKeysWithValues: delegate.receivedSpaces.map { ($0.spaceID, $0) })
        XCTAssertEqual(spacesByID["101"]?.spaceName, "ALPHA")
        XCTAssertEqual(spacesByID["102"]?.spaceName, "BETA")
        // New space 201 has an unknown ID → position fallback to the disconnected display-X
        XCTAssertEqual(spacesByID["201"]?.spaceName, "OLDEXT")
        // ID-matched entries keep their stored position during the topology change
        XCTAssertEqual(nameStore.loadAll()["101"]?.positionOnDisplay, 2)
    }

    // MARK: - Strategy Selection: Display Without Stored Entries (ID-first)

    /// Normal operation (no wake, no topology change), but the store has no entries for the
    /// connected display UUID → .idWithPositionFallback, so the disconnected fallback can recover names.
    func testNormalUpdate_displayWithoutStoredEntries_usesIdWithPositionFallback() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        // First update — clears revalidation flag, sets _lastKnownDisplayIDs
        runUpdate()

        // Replace the store: only an entry for a display that is no longer connected
        nameStore.save(["900": SpaceNameInfo(
            spaceNum: 1, spaceName: "RECOVERED", spaceLabel: "1",
            displayUUID: "display-X", positionOnDisplay: 1)])

        runUpdate(trigger: .spaceSwitch)

        // .idOnly would find nothing for ID 101 and show "---"
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "RECOVERED")
    }

    // MARK: - Strategy Selection: Wake + Topology Change (Topology Wins)

    /// When both wake and topology change happen (e.g., sleep→mirror→wake),
    /// topology wins: .idWithPositionFallback is used (not .positionOnly).
    /// This is issue #29.
    func testWakePlusTopologyChange_topologyWins() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: false)
            ])]
        }

        // First update — establishes topology as {display-A}
        runUpdate()

        // Store names under their IDs
        nameStore.update { stored in
            stored["101"] = SpaceNameInfo(
                spaceNum: 1, spaceName: "MAIN", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["102"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "DEV", spaceLabel: "2",
                displayUUID: "display-A", positionOnDisplay: 2)
        }

        // Simulate wake
        simulateWake()

        // Topology also changed: display-A is replaced by mirror display-M. The IDs survived,
        // but while macOS reconfigures, the spaces sit in a transient order: 102 first, 101 second.
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-M", currentSpaceID: 102, spaces: [
                (id: 102, isFullScreen: false),
                (id: 101, isFullScreen: false)
            ])]
        }

        runUpdate(trigger: .spaceSwitch)

        // Topology wins → .idWithPositionFallback → names follow the IDs.
        // If wake won (.positionOnly), the disconnected-display fallback would match by position
        // against display-A and give "MAIN" to space 102 and "DEV" to space 101.
        XCTAssertEqual(delegate.receivedSpaces[0].spaceID, "102")
        XCTAssertEqual(delegate.receivedSpaces[0].spaceName, "DEV")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceID, "101")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "MAIN")
    }

    // MARK: - Grace Period

    /// After a topology change, the grace period keeps .idWithPositionFallback
    /// active for several follow-up updates, so the preserved position survives them (issue #22d).
    func testGracePeriod_preventsIdOnlyAfterTopologyChange() {
        // Lid close: space 201 ("EXT", stored at display-B/pos 1) now sits at display-A/pos 3.
        // The topology update set the counter to 5 and decremented it to 4.
        runLidCloseScenario()

        // display-A has stored entries and there is no wake and no new topology change, so
        // without the grace period these follow-up updates would use .idOnly and overwrite
        // 201's preserved display-B/pos 1 with the transient display-A/pos 3.
        // The 4 remaining grace-period updates run with counter 4 → 3 → 2 → 1 → 0.
        for followUpNumber in 1...4 {
            runUpdate(trigger: .spaceSwitch)
            let stored = nameStore.loadAll()
            XCTAssertEqual(stored["201"]?.displayUUID, "display-B", "follow-up update \(followUpNumber)")
            XCTAssertEqual(stored["201"]?.positionOnDisplay, 1, "follow-up update \(followUpNumber)")
        }
        XCTAssertEqual(delegate.receivedSpaces[2].spaceName, "EXT")
    }

    /// Grace period counts down to zero, after which .idOnly resumes.
    func testGracePeriod_expiresAfterEnoughUpdates() {
        // Topology update sets the counter to 5 and decrements it to 4 in the same update
        runLidCloseScenario()

        // Exhaust the grace period: 4 follow-up updates (4 → 3 → 2 → 1 → 0)
        for _ in 0..<4 {
            runUpdate(trigger: .spaceSwitch)
        }
        XCTAssertEqual(nameStore.loadAll()["201"]?.positionOnDisplay, 1,
                       "Position is still preserved during the grace period")

        // This update should use .idOnly (grace period expired, no wake),
        // which stores the current display/position of the ID-matched entry
        runUpdate(trigger: .spaceSwitch)
        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["201"]?.spaceName, "EXT")
        XCTAssertEqual(stored["201"]?.displayUUID, "display-A")
        XCTAssertEqual(stored["201"]?.positionOnDisplay, 3)
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
                spaceNum: 3, spaceName: "EXT", spaceLabel: "1",
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
                spaceNum: 2, spaceName: "EXT", spaceLabel: "1",
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
                spaceNum: 1, spaceName: "LAPTOP", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1)
            stored["201"] = SpaceNameInfo(
                spaceNum: 2, spaceName: "MONITOR", spaceLabel: "1",
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
    func testNoSave_whenDataUnchanged() throws {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false)
            ])]
        }

        // First update — stores initial data
        runUpdate()

        // Re-write the same entries as an XML plist. SpaceNameStore.save() writes binary plists,
        // so if the second update saved, the raw bytes would change even though the entries are equal.
        let xmlEncoder = PropertyListEncoder()
        xmlEncoder.outputFormat = .xml
        let xmlData = try xmlEncoder.encode(nameStore.loadAll())
        testDefaults.set(xmlData, forKey: "spaceNames")

        // Second update with same data
        runUpdate(trigger: .spaceSwitch)

        // Raw data should be untouched (store was not modified unnecessarily)
        XCTAssertEqual(testDefaults.data(forKey: "spaceNames"), xmlData,
                       "Store must not be saved when the merged names equal the stored names")
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
            spaceNum: 1, spaceName: "RED", spaceLabel: "1",
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

        // The setting is read from UserDefaults.standard when the update starts
        withStandardDefault("restartNumberingByDisplay", setTo: true) {
            runUpdate()
        }

        // With restart numbering, each display starts from "1"
        XCTAssertEqual(delegate.receivedSpaces[0].spaceLabel, "1")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceLabel, "2")
        XCTAssertEqual(delegate.receivedSpaces[2].spaceLabel, "1",
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

        XCTAssertEqual(delegate.receivedSpaces[0].spaceLabel, "1")
        XCTAssertEqual(delegate.receivedSpaces[1].spaceLabel, "F1")
        XCTAssertEqual(delegate.receivedSpaces[2].spaceLabel, "F2")
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

        // No stored name and no PID in the space dict → treated as an auto-named fullscreen space;
        // FullscreenNaming.complete.displayName(forApp: nil) gives "FULL". The preference is read
        // from UserDefaults.standard during the update, so pin it to .complete.
        withStandardDefault("fullscreenNaming", setTo: FullscreenNaming.complete.rawValue) {
            runUpdate()
        }

        XCTAssertEqual(delegate.receivedSpaces[1].spaceName, "FULL")
    }

    /// A first-seen regular space is stored with the placeholder "---" as its name. That counts as
    /// user data (current behaviour, kept deliberately). An auto-named fullscreen space is stored with
    /// an empty name, so that a later change of the fullscreen naming preference still applies to it.
    func testFirstSeenSpaces_storedNames() {
        observer.displaySpacesProvider = {
            [makeDisplay(id: "display-A", currentSpaceID: 101, spaces: [
                (id: 101, isFullScreen: false),
                (id: 102, isFullScreen: true)
            ])]
        }

        runUpdate()

        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["101"]?.spaceName, "---")
        XCTAssertEqual(stored["101"]?.hasUserData, true)
        XCTAssertEqual(stored["102"]?.spaceName, "")
        XCTAssertEqual(stored["102"]?.hasUserData, false)
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
