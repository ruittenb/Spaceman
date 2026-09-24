//
//  AutoShrinkTests.swift
//  SpacemanTests
//
//  Tests for fit-to-width: which triggers retry the user's size, and how the
//  icon size steps down when the menu bar has no room.
//

import XCTest
@testable import Spaceman

final class AutoShrinkTests: XCTestCase {

    // MARK: - SpaceUpdateTrigger reset behavior

    func testSpaceSwitchKeepsFittedSize() {
        XCTAssertFalse(SpaceUpdateTrigger.spaceSwitch.resetsFittedSize)
    }

    func testTopologyChangeResetsFittedSize() {
        XCTAssertTrue(SpaceUpdateTrigger.topologyChange.resetsFittedSize)
    }

    func testUserRefreshResetsFittedSize() {
        XCTAssertTrue(SpaceUpdateTrigger.userRefresh.resetsFittedSize)
    }

    func testSessionActiveResetsFittedSize() {
        XCTAssertTrue(SpaceUpdateTrigger.sessionActive.resetsFittedSize)
    }

    func testAutoRefreshKeepsFittedSize() {
        XCTAssertFalse(SpaceUpdateTrigger.autoRefresh.resetsFittedSize)
    }

    // MARK: - IconSize.nextSmaller

    func testNextSmallerSingleRowWalksEverySize() {
        XCTAssertEqual(IconSize.enormous.nextSmaller(twoRows: false), .extraLarge)
        XCTAssertEqual(IconSize.extraLarge.nextSmaller(twoRows: false), .large)
        XCTAssertEqual(IconSize.large.nextSmaller(twoRows: false), .medium)
        XCTAssertEqual(IconSize.medium.nextSmaller(twoRows: false), .compact)
        XCTAssertEqual(IconSize.compact.nextSmaller(twoRows: false), .narrow)
        XCTAssertNil(IconSize.narrow.nextSmaller(twoRows: false))
    }

    func testNextSmallerTwoRowsSkipsSizesWithoutEntry() {
        // narrow has no two-row entry, so compact is the floor
        XCTAssertNil(IconSize.compact.nextSmaller(twoRows: true))
        XCTAssertEqual(IconSize.medium.nextSmaller(twoRows: true), .compact)
        XCTAssertEqual(IconSize.large.nextSmaller(twoRows: true), .medium)
    }

    func testNextSmallerTwoRowsAlwaysReturnsSizeWithEntry() {
        for size in IconSize.allCases {
            if let next = size.nextSmaller(twoRows: true) {
                XCTAssertNotNil(Constants.sizesTwoRows[next], "\(size) stepped down to \(next), which has no entry")
                XCTAssertLessThan(next.rawValue, size.rawValue)
            }
        }
    }
}
