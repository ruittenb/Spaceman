//
//  PreferencesViewModelTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class PreferencesViewModelTests: XCTestCase {

    private var vm: PreferencesViewModel!
    private var nameStore: SpaceNameStore!
    private var savedActiveIDs: Set<String>!

    override func setUp() {
        super.setUp()
        let suiteName = "PreferencesViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        nameStore = SpaceNameStore(defaults: defaults)
        vm = PreferencesViewModel(nameStore: nameStore)

        // Save and restore AppDelegate.activeSpaceIDs
        savedActiveIDs = AppDelegate.activeSpaceIDs
    }

    override func tearDown() {
        AppDelegate.activeSpaceIDs = savedActiveIDs
        vm = nil
        nameStore = nil
        super.tearDown()
    }

    // MARK: - loadData

    func testLoadData_filtersToActiveSpaces() {
        nameStore.save([
            "1": SpaceNameInfo(spaceNum: 1, spaceName: "A", spaceLabel: "1"),
            "2": SpaceNameInfo(spaceNum: 2, spaceName: "B", spaceLabel: "2"),
            "3": SpaceNameInfo(spaceNum: 3, spaceName: "C", spaceLabel: "3")
        ])
        AppDelegate.activeSpaceIDs = ["1", "3"]

        vm.loadData()

        XCTAssertEqual(vm.spaceNamesDict.count, 2)
        XCTAssertNotNil(vm.spaceNamesDict["1"])
        XCTAssertNil(vm.spaceNamesDict["2"])
        XCTAssertNotNil(vm.spaceNamesDict["3"])
    }

    func testLoadData_emptyActiveSpaces_resultsInDummyEntry() {
        AppDelegate.activeSpaceIDs = []

        vm.loadData()

        XCTAssertEqual(vm.sortedSpaceNamesDict.count, 1)
        XCTAssertEqual(vm.sortedSpaceNamesDict[0].key, "0")
        XCTAssertEqual(vm.sortedSpaceNamesDict[0].value.spaceName, "DISP")
    }

    // MARK: - Sorting

    func testSortedSpaceNames_sortsByDisplayThenPosition() {
        nameStore.save([
            "A": SpaceNameInfo(
                spaceNum: 1, spaceName: "d2p1", spaceLabel: "1",
                displayUUID: "disp-2", positionOnDisplay: 1,
                currentDisplayIndex: 2, currentSpaceNumber: 3),
            "B": SpaceNameInfo(
                spaceNum: 2, spaceName: "d1p2", spaceLabel: "2",
                displayUUID: "disp-1", positionOnDisplay: 2,
                currentDisplayIndex: 1, currentSpaceNumber: 2),
            "C": SpaceNameInfo(
                spaceNum: 3, spaceName: "d1p1", spaceLabel: "1",
                displayUUID: "disp-1", positionOnDisplay: 1,
                currentDisplayIndex: 1, currentSpaceNumber: 1)
        ])
        AppDelegate.activeSpaceIDs = ["A", "B", "C"]

        vm.loadData()

        XCTAssertEqual(vm.sortedSpaceNamesDict.map { $0.value.spaceName },
                       ["d1p1", "d1p2", "d2p1"])
    }

    // MARK: - Color handling

    func testUpdateSpaceColor_persistsToStore() {
        nameStore.save([
            "101": SpaceNameInfo(spaceNum: 1, spaceName: "TEST", spaceLabel: "1")
        ])
        AppDelegate.activeSpaceIDs = ["101"]
        vm.loadData()

        vm.updateSpaceColor(for: "101", to: NSColor.red)

        let stored = nameStore.loadAll()
        XCTAssertNotNil(stored["101"]?.colorHex, "Color should be persisted to store")
    }

    func testUpdateSpaceColor_preservesDisconnectedEntries() {
        nameStore.save([
            "101": SpaceNameInfo(
                spaceNum: 1, spaceName: "ACTIVE", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1),
            "201": SpaceNameInfo(
                spaceNum: 2, spaceName: "DISCONNECTED", spaceLabel: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        ])
        AppDelegate.activeSpaceIDs = ["101"]  // Only 101 is active
        vm.loadData()

        vm.updateSpaceColor(for: "101", to: NSColor.blue)

        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["201"]?.spaceName, "DISCONNECTED",
                       "Disconnected display entry must survive color update")
    }

    // MARK: - Remove all colors

    func testRemoveAllColors_clearsFromStoreAndMemory() {
        nameStore.save([
            "101": SpaceNameInfo(
                spaceNum: 1, spaceName: "A", spaceLabel: "1",
                displayUUID: nil, positionOnDisplay: nil,
                currentDisplayIndex: nil, currentSpaceNumber: nil,
                colorHex: "FF0000"),
            "102": SpaceNameInfo(
                spaceNum: 2, spaceName: "B", spaceLabel: "2",
                displayUUID: nil, positionOnDisplay: nil,
                currentDisplayIndex: nil, currentSpaceNumber: nil,
                colorHex: "00FF00")
        ])
        AppDelegate.activeSpaceIDs = ["101", "102"]
        vm.loadData()

        vm.removeAllColors()

        // Check in-memory
        XCTAssertNil(vm.spaceNamesDict["101"]?.colorHex)
        XCTAssertNil(vm.spaceNamesDict["102"]?.colorHex)

        // Check store
        let stored = nameStore.loadAll()
        XCTAssertNil(stored["101"]?.colorHex)
        XCTAssertNil(stored["102"]?.colorHex)
    }

    // MARK: - persistChanges

    func testPersistChanges_usesUpdateNotSave() {
        nameStore.save([
            "101": SpaceNameInfo(
                spaceNum: 1, spaceName: "ACTIVE", spaceLabel: "1",
                displayUUID: "display-A", positionOnDisplay: 1),
            "201": SpaceNameInfo(
                spaceNum: 2, spaceName: "DISCONNECTED", spaceLabel: "1",
                displayUUID: "display-B", positionOnDisplay: 1)
        ])
        AppDelegate.activeSpaceIDs = ["101"]
        vm.loadData()

        // Modify an active entry
        vm.updateSpace(for: "101", to: "RENAMED")
        vm.persistChanges(for: "101")

        let stored = nameStore.loadAll()
        XCTAssertEqual(stored["101"]?.spaceName, "RENAMED")
        XCTAssertEqual(stored["201"]?.spaceName, "DISCONNECTED",
                       "persistChanges must use update(), not save(), to preserve disconnected entries")
    }
}
