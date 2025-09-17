import XCTest
@testable import Spaceman

final class SpaceNameStoreTests: XCTestCase {
    func testLoadReturnsEmptyWhenNoData() {
        let defaults = UserDefaults(suiteName: "dev.ruittenb.Spaceman.SpaceNameStoreTests")!
        defaults.removePersistentDomain(forName: "dev.ruittenb.Spaceman.SpaceNameStoreTests")
        let store = SpaceNameStore(defaults: defaults)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testSaveAndLoadRoundTripsValues() {
        let defaults = UserDefaults(suiteName: "dev.ruittenb.Spaceman.SpaceNameStoreTests")!
        defaults.removePersistentDomain(forName: "dev.ruittenb.Spaceman.SpaceNameStoreTests")
        let store = SpaceNameStore(defaults: defaults)
        let sample = [
            "1": SpaceNameInfo(spaceNum: 1, spaceName: "WORK", spaceByDesktopID: "1"),
            "2": SpaceNameInfo(spaceNum: 2, spaceName: "PLAY", spaceByDesktopID: "2")
        ]
        store.save(sample)
        let loaded = store.loadAll()
        XCTAssertEqual(sample.count, loaded.count)
        XCTAssertEqual(sample["1"], loaded["1"])
        XCTAssertEqual(sample["2"], loaded["2"])
    }

    func testUpdateMutatesStoredDictionary() {
        let defaults = UserDefaults(suiteName: "dev.ruittenb.Spaceman.SpaceNameStoreTests")!
        defaults.removePersistentDomain(forName: "dev.ruittenb.Spaceman.SpaceNameStoreTests")
        let store = SpaceNameStore(defaults: defaults)
        store.save(["1": SpaceNameInfo(spaceNum: 1, spaceName: "INIT", spaceByDesktopID: "1")])

        store.update { names in
            names["1"] = SpaceNameInfo(spaceNum: 1, spaceName: "UPDATED", spaceByDesktopID: "1")
            names["2"] = SpaceNameInfo(spaceNum: 2, spaceName: "ADDED", spaceByDesktopID: "2")
        }

        let loaded = store.loadAll()
        XCTAssertEqual("UPDATED", loaded["1"]?.spaceName)
        XCTAssertEqual("ADDED", loaded["2"]?.spaceName)
    }
}
