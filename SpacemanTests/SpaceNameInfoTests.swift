//
//  SpaceNameInfoTests.swift
//  SpacemanTests
//
//  Created by Claude Code
//

import XCTest
@testable import Spaceman

final class SpaceNameInfoTests: XCTestCase {

    func testSpaceNameInfoInitialization() {
        let info = SpaceNameInfo(
            spaceNum: 1,
            spaceName: "Development",
            spaceByDesktopID: "1",
            displayUUID: "uuid-1",
            positionOnDisplay: 1,
            currentDisplayIndex: 1,
            currentSpaceNumber: 1
        )

        XCTAssertEqual(info.spaceNum, 1)
        XCTAssertEqual(info.spaceName, "Development")
        XCTAssertEqual(info.spaceByDesktopID, "1")
        XCTAssertEqual(info.displayUUID, "uuid-1")
        XCTAssertEqual(info.positionOnDisplay, 1)
        XCTAssertEqual(info.currentDisplayIndex, 1)
        XCTAssertEqual(info.currentSpaceNumber, 1)
    }

    func testSpaceNameInfoMinimalInitialization() {
        let info = SpaceNameInfo(
            spaceNum: 2,
            spaceName: "Minimal",
            spaceByDesktopID: "2"
        )

        XCTAssertEqual(info.spaceNum, 2)
        XCTAssertEqual(info.spaceName, "Minimal")
        XCTAssertEqual(info.spaceByDesktopID, "2")
        XCTAssertNil(info.displayUUID)
        XCTAssertNil(info.positionOnDisplay)
        XCTAssertNil(info.currentDisplayIndex)
        XCTAssertNil(info.currentSpaceNumber)
    }

    func testSpaceNameInfoHashable() {
        let info1 = SpaceNameInfo(spaceNum: 1, spaceName: "Test", spaceByDesktopID: "1")
        let info2 = SpaceNameInfo(spaceNum: 1, spaceName: "Test", spaceByDesktopID: "1")
        let info3 = SpaceNameInfo(spaceNum: 2, spaceName: "Test", spaceByDesktopID: "2")

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
            spaceByDesktopID: "3",
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
}
