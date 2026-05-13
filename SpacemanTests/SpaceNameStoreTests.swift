//
//  SpaceNameStoreTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class SpaceNameStoreTests: XCTestCase {

    private var store: SpaceNameStore!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SpaceNameStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = SpaceNameStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        super.tearDown()
    }

    func testLoadAll_emptyStore_returnsEmptyDict() {
        XCTAssertEqual(store.loadAll(), [:])
    }

    func testSaveAndLoad_roundTrip() {
        let entry = SpaceNameInfo(
            spaceNum: 1, spaceName: "HOME", spaceByDesktopID: "1",
            displayUUID: "display-A", positionOnDisplay: 1,
            currentDisplayIndex: 1, currentSpaceNumber: 1,
            colorHex: "FF0000")
        let data: [String: SpaceNameInfo] = ["101": entry]

        store.save(data)
        let loaded = store.loadAll()

        XCTAssertEqual(loaded["101"], entry)
    }

    func testUpdate_mergesIntoExisting() {
        store.save([
            "101": SpaceNameInfo(spaceNum: 1, spaceName: "ONE", spaceByDesktopID: "1"),
            "102": SpaceNameInfo(spaceNum: 2, spaceName: "TWO", spaceByDesktopID: "2")
        ])

        store.update { names in
            names["101"] = names["101"]?.withName("MODIFIED")
        }

        let loaded = store.loadAll()
        XCTAssertEqual(loaded["101"]?.spaceName, "MODIFIED")
        XCTAssertEqual(loaded["102"]?.spaceName, "TWO",
                       "Untouched entry should be preserved by update()")
    }

    func testUpdate_preservesEntriesNotInClosure() {
        // Simulate disconnected display entry
        store.save([
            "101": SpaceNameInfo(
                spaceNum: 1, spaceName: "LAPTOP", spaceByDesktopID: "1",
                displayUUID: "display-A", positionOnDisplay: 1),
            "201": SpaceNameInfo(
                spaceNum: 2, spaceName: "MONITOR", spaceByDesktopID: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        ])

        // Only touch the active space — disconnected entry must survive
        store.update { names in
            names["101"] = names["101"]?.withColor("00FF00")
        }

        let loaded = store.loadAll()
        XCTAssertEqual(loaded["101"]?.colorHex, "00FF00")
        XCTAssertEqual(loaded["201"]?.spaceName, "MONITOR",
                       "Disconnected display entry must survive update()")
    }

    func testConcurrentReadsAndWrites_noCorruption() {
        store.save(["101": SpaceNameInfo(spaceNum: 1, spaceName: "INIT", spaceByDesktopID: "1")])

        let group = DispatchGroup()
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                self.store.update { names in
                    names["101"] = names["101"]?.withName("V\(i)")
                }
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                _ = self.store.loadAll()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "Concurrent operations should complete without deadlock")

        // Final state should have one of the written values
        let loaded = store.loadAll()
        XCTAssertNotNil(loaded["101"])
        XCTAssertTrue(loaded["101"]!.spaceName.hasPrefix("V"),
                      "Final value should be one of the concurrent writes")
    }

    func testCorruptedData_returnsEmptyDict() {
        // Write garbage bytes to the defaults key
        defaults.set(Data([0xFF, 0xFE, 0x00, 0x01]), forKey: "spaceNames")

        let loaded = store.loadAll()
        XCTAssertEqual(loaded, [:], "Corrupted data should return empty dict, not crash")
    }
}
