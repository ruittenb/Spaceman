//
//  SpaceNameInfoTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 13/10/2025.
//

import XCTest
@testable import Spaceman

final class SpaceNameInfoTests: XCTestCase {

    func testSpaceNameInfoHashable() {
        let info1 = SpaceNameInfo(spaceNum: 1, spaceName: "Test", spaceLabel: "1")
        let info2 = SpaceNameInfo(spaceNum: 1, spaceName: "Test", spaceLabel: "1")
        let info3 = SpaceNameInfo(spaceNum: 2, spaceName: "Test", spaceLabel: "2")

        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)

        var set: Set<SpaceNameInfo> = []
        set.insert(info1)
        set.insert(info2)
        set.insert(info3)

        XCTAssertEqual(set.count, 2) // info1 and info2 are duplicates
    }

    func testSpaceNameInfoCodable() throws {
        let original = SpaceNameInfo(
            spaceNum: 3,
            spaceName: "Coding Test",
            spaceLabel: "3",
            displayUUID: "test-uuid",
            positionOnDisplay: 2,
            currentDisplayIndex: 1,
            currentSpaceNumber: 3
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SpaceNameInfo.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.spaceNum, 3)
        XCTAssertEqual(decoded.spaceName, "Coding Test")
        XCTAssertEqual(decoded.displayUUID, "test-uuid")
        XCTAssertEqual(decoded.positionOnDisplay, 2)
    }

    /// SpaceNameStore persists with PropertyListEncoder, so round-trip through that format too.
    func testSpaceNameInfoPropertyListRoundTrip_includesColorHex() throws {
        let original = SpaceNameInfo(
            spaceNum: 3,
            spaceName: "Coding Test",
            spaceLabel: "3",
            displayUUID: "test-uuid",
            positionOnDisplay: 2,
            currentDisplayIndex: 1,
            currentSpaceNumber: 3,
            colorHex: "FF5733"
        )

        let data = try PropertyListEncoder().encode(["101": original])
        let decoded = try PropertyListDecoder().decode([String: SpaceNameInfo].self, from: data)

        XCTAssertEqual(decoded["101"], original)
        XCTAssertEqual(decoded["101"]?.colorHex, "FF5733")
    }

    // MARK: - withName / withColor

    func testWithName_changesOnlyName() {
        let original = SpaceNameInfo(
            spaceNum: 1, spaceName: "Old", spaceLabel: "1",
            displayUUID: "D1", positionOnDisplay: 1,
            currentDisplayIndex: 1, currentSpaceNumber: 1,
            colorHex: "FF5733")

        let renamed = original.withName("New")

        var expected = original
        expected.spaceName = "New"
        XCTAssertEqual(renamed, expected)
        XCTAssertEqual(original.spaceName, "Old", "Original must be unchanged")
    }

    func testWithColor_changesOnlyColor() {
        let original = SpaceNameInfo(
            spaceNum: 1, spaceName: "Work", spaceLabel: "1",
            displayUUID: "D1", positionOnDisplay: 1,
            currentDisplayIndex: 1, currentSpaceNumber: 1,
            colorHex: "FF5733")

        let recolored = original.withColor("00FF00")
        var expected = original
        expected.colorHex = "00FF00"
        XCTAssertEqual(recolored, expected)
        XCTAssertEqual(original.colorHex, "FF5733", "Original must be unchanged")

        XCTAssertNil(original.withColor(nil).colorHex, "nil clears the color")
    }

    // MARK: - hasUserData

    func testHasUserData_WithName() {
        let info = SpaceNameInfo(spaceNum: 1, spaceName: "Work", spaceLabel: "1")
        XCTAssertTrue(info.hasUserData)
    }

    func testHasUserData_WithColor() {
        var info = SpaceNameInfo(spaceNum: 1, spaceName: "", spaceLabel: "1")
        info.colorHex = "FF5733"
        XCTAssertTrue(info.hasUserData)
    }

    func testHasUserData_Empty() {
        let info = SpaceNameInfo(spaceNum: 1, spaceName: "", spaceLabel: "1")
        XCTAssertFalse(info.hasUserData)
    }

    /// SpaceObserver stores the placeholder "---" as the name of an unnamed regular space.
    /// It counts as user data: current behaviour, kept deliberately.
    func testHasUserData_PlaceholderName_CountsAsUserData() {
        let info = SpaceNameInfo(spaceNum: 1, spaceName: "---", spaceLabel: "1")
        XCTAssertTrue(info.hasUserData)
    }
}
