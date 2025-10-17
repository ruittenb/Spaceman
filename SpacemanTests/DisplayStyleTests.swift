//
//  DisplayStyleTests.swift
//  SpacemanTests
//
//  Created by Claude Code
//

import XCTest
@testable import Spaceman

final class DisplayStyleTests: XCTestCase {

    // IMPORTANT: These raw values are stored in UserDefaults and must remain
    // stable across app versions to preserve user preferences during upgrades.
    // Changing these values would reset users' display style settings.
    func testDisplayStyleRawValues() {
        XCTAssertEqual(DisplayStyle.rects.rawValue, 0)
        XCTAssertEqual(DisplayStyle.numbers.rawValue, 1)
        XCTAssertEqual(DisplayStyle.numbersAndRects.rawValue, 2)
        XCTAssertEqual(DisplayStyle.names.rawValue, 3)
        XCTAssertEqual(DisplayStyle.numbersAndNames.rawValue, 4)
    }

    func testDisplayStyleAllCases() {
        let allCases = DisplayStyle.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.rects))
        XCTAssertTrue(allCases.contains(.numbers))
        XCTAssertTrue(allCases.contains(.numbersAndRects))
        XCTAssertTrue(allCases.contains(.names))
        XCTAssertTrue(allCases.contains(.numbersAndNames))
    }

    func testDisplayStyleInitFromRawValue() {
        XCTAssertEqual(DisplayStyle(rawValue: 0), .rects)
        XCTAssertEqual(DisplayStyle(rawValue: 1), .numbers)
        XCTAssertEqual(DisplayStyle(rawValue: 2), .numbersAndRects)
        XCTAssertEqual(DisplayStyle(rawValue: 3), .names)
        XCTAssertEqual(DisplayStyle(rawValue: 4), .numbersAndNames)
        XCTAssertNil(DisplayStyle(rawValue: 99))
    }
}
