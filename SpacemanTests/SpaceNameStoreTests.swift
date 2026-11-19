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
            spaceNum: 1, spaceName: "HOME", spaceLabel: "1",
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
            "101": SpaceNameInfo(spaceNum: 1, spaceName: "ONE", spaceLabel: "1"),
            "102": SpaceNameInfo(spaceNum: 2, spaceName: "TWO", spaceLabel: "2")
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
                spaceNum: 1, spaceName: "LAPTOP", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1),
            "201": SpaceNameInfo(
                spaceNum: 2, spaceName: "MONITOR", spaceLabel: "1",
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

    func testConcurrentReadsAndWrites_noLostUpdates() {
        let group = DispatchGroup()
        let iterations = 100

        // Each update adds its own key. If update() did not load, mutate and write atomically,
        // concurrent updates would overwrite each other and keys would go missing.
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                self.store.update { names in
                    names["\(i)"] = SpaceNameInfo(spaceNum: i, spaceName: "V\(i)", spaceLabel: "\(i)")
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

        // Every concurrent write must have survived
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, iterations, "No update may be lost")
        XCTAssertEqual(loaded["42"]?.spaceName, "V42")
    }

    func testSave_replacesEntireStore() {
        store.save([
            "101": SpaceNameInfo(spaceNum: 1, spaceName: "ONE", spaceLabel: "1"),
            "102": SpaceNameInfo(spaceNum: 2, spaceName: "TWO", spaceLabel: "2")
        ])

        let replacement = ["103": SpaceNameInfo(spaceNum: 3, spaceName: "THREE", spaceLabel: "3")]
        store.save(replacement)

        XCTAssertEqual(store.loadAll(), replacement,
                       "save() replaces the whole store; callers with a subset must use update()")
    }

    func testSetName_nil_removesEntry() {
        let entry = SpaceNameInfo(spaceNum: 1, spaceName: "HOME", spaceLabel: "1")
        store.setName(entry, for: "101")
        store.setName(SpaceNameInfo(spaceNum: 2, spaceName: "OTHER", spaceLabel: "2"), for: "102")
        XCTAssertEqual(store.loadAll()["101"], entry)

        store.setName(nil, for: "101")

        let loaded = store.loadAll()
        XCTAssertNil(loaded["101"])
        XCTAssertEqual(loaded["102"]?.spaceName, "OTHER", "Other entries must be untouched")
    }

    func testNameInfoForSpaceID() {
        let entry = SpaceNameInfo(spaceNum: 1, spaceName: "HOME", spaceLabel: "1")
        store.save(["101": entry])

        XCTAssertEqual(store.nameInfo(for: "101"), entry)
        XCTAssertNil(store.nameInfo(for: "999"))
    }

    func testCorruptedData_returnsEmptyDict() {
        // Write garbage bytes to the defaults key
        defaults.set(Data([0xFF, 0xFE, 0x00, 0x01]), forKey: "spaceNames")

        let loaded = store.loadAll()
        XCTAssertEqual(loaded, [:], "Corrupted data should return empty dict, not crash")
    }
}
