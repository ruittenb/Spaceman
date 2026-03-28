//
//  IconTextTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 13/10/2025.
//

import XCTest
@testable import Spaceman

final class IconTextTests: XCTestCase {

    // IMPORTANT: These raw values are stored in UserDefaults and must remain
    // stable across app versions to preserve user preferences during upgrades.
    // Changing these values would reset users' display style settings.
    func testIconTextRawValues() {
        XCTAssertEqual(IconText.noText.rawValue, 0)
        XCTAssertEqual(IconText.numbers.rawValue, 2)
        XCTAssertEqual(IconText.names.rawValue, 3)
        XCTAssertEqual(IconText.numbersAndNames.rawValue, 4)
    }

    func testIconTextAllCases() {
        let allCases = IconText.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.noText))
        XCTAssertTrue(allCases.contains(.numbers))
        XCTAssertTrue(allCases.contains(.names))
        XCTAssertTrue(allCases.contains(.numbersAndNames))
    }

    func testIconTextInitFromRawValue() {
        XCTAssertEqual(IconText(rawValue: 0), .noText)
        XCTAssertNil(IconText(rawValue: 1)) // was bare numbers, now migrated away
        XCTAssertEqual(IconText(rawValue: 2), .numbers)
        XCTAssertEqual(IconText(rawValue: 3), .names)
        XCTAssertEqual(IconText(rawValue: 4), .numbersAndNames)
        XCTAssertNil(IconText(rawValue: 99))
    }
}
