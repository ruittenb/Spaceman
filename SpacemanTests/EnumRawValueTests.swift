//
//  EnumRawValueTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 20/03/2026.
//
//  Raw value stability tests for all Int-backed enums persisted via @AppStorage.
//
//  WHY THESE TESTS EXIST:
//  These enums are stored in UserDefaults as integers. If a raw value changes
//  (e.g. by reordering cases, removing a case, or bumping a number), the stored
//  integer no longer maps to the intended case. @AppStorage will decode it as nil
//  and silently fall back to the default, resetting the user's preference on
//  upgrade. These tests catch that before it ships.
//

import XCTest
@testable import Spaceman

final class EnumRawValueTests: XCTestCase {

    // MARK: - InactiveStyle

    func testInactiveStyleRawValues() {
        XCTAssertEqual(InactiveStyle.bordered.rawValue, 0)
        XCTAssertEqual(InactiveStyle.dimmed.rawValue, 1)
    }

    func testInactiveStyleAllCases() {
        XCTAssertEqual(InactiveStyle.allCases.count, 2)
    }

    func testInactiveStyleInitFromRawValue() {
        XCTAssertEqual(InactiveStyle(rawValue: 0), .bordered)
        XCTAssertEqual(InactiveStyle(rawValue: 1), .dimmed)
        XCTAssertNil(InactiveStyle(rawValue: 99))
    }

    // MARK: - LayoutMode

    func testLayoutModeRawValues() {
        XCTAssertEqual(LayoutMode.dualRows.rawValue, 0)
        XCTAssertEqual(LayoutMode.compact.rawValue, 1)
        XCTAssertEqual(LayoutMode.medium.rawValue, 2)
        XCTAssertEqual(LayoutMode.large.rawValue, 3)
        XCTAssertEqual(LayoutMode.extraLarge.rawValue, 4)
    }

    func testLayoutModeAllCases() {
        XCTAssertEqual(LayoutMode.allCases.count, 6)
    }

    func testLayoutModeInitFromRawValue() {
        XCTAssertEqual(LayoutMode(rawValue: 0), .dualRows)
        XCTAssertEqual(LayoutMode(rawValue: 1), .compact)
        XCTAssertEqual(LayoutMode(rawValue: 2), .medium)
        XCTAssertEqual(LayoutMode(rawValue: 3), .large)
        XCTAssertEqual(LayoutMode(rawValue: 4), .extraLarge)
        XCTAssertNil(LayoutMode(rawValue: 99))
    }

    // MARK: - DualRowFillOrder

    func testDualRowFillOrderRawValues() {
        XCTAssertEqual(DualRowFillOrder.byColumn.rawValue, 0)
        XCTAssertEqual(DualRowFillOrder.byRow.rawValue, 1)
    }

    func testDualRowFillOrderAllCases() {
        XCTAssertEqual(DualRowFillOrder.allCases.count, 2)
    }

    func testDualRowFillOrderInitFromRawValue() {
        XCTAssertEqual(DualRowFillOrder(rawValue: 0), .byColumn)
        XCTAssertEqual(DualRowFillOrder(rawValue: 1), .byRow)
        XCTAssertNil(DualRowFillOrder(rawValue: 99))
    }

    // MARK: - VisibleSpacesMode

    func testVisibleSpacesModeRawValues() {
        XCTAssertEqual(VisibleSpacesMode.all.rawValue, 0)
        XCTAssertEqual(VisibleSpacesMode.neighbors.rawValue, 1)
        XCTAssertEqual(VisibleSpacesMode.currentOnly.rawValue, 2)
    }

    func testVisibleSpacesModeAllCases() {
        XCTAssertEqual(VisibleSpacesMode.allCases.count, 3)
    }

    func testVisibleSpacesModeInitFromRawValue() {
        XCTAssertEqual(VisibleSpacesMode(rawValue: 0), .all)
        XCTAssertEqual(VisibleSpacesMode(rawValue: 1), .neighbors)
        XCTAssertEqual(VisibleSpacesMode(rawValue: 2), .currentOnly)
        XCTAssertNil(VisibleSpacesMode(rawValue: 99))
    }

    // MARK: - HorizontalDirection

    func testHorizontalDirectionRawValues() {
        XCTAssertEqual(HorizontalDirection.defaultOrder.rawValue, 0)
        XCTAssertEqual(HorizontalDirection.reverseOrder.rawValue, 1)
    }

    func testHorizontalDirectionInitFromRawValue() {
        XCTAssertEqual(HorizontalDirection(rawValue: 0), .defaultOrder)
        XCTAssertEqual(HorizontalDirection(rawValue: 1), .reverseOrder)
        XCTAssertNil(HorizontalDirection(rawValue: 99))
    }

    // MARK: - VerticalDirection

    func testVerticalDirectionRawValues() {
        XCTAssertEqual(VerticalDirection.defaultOrder.rawValue, 0)
        XCTAssertEqual(VerticalDirection.topGoesFirst.rawValue, 1)
        XCTAssertEqual(VerticalDirection.bottomGoesFirst.rawValue, 2)
    }

    func testVerticalDirectionInitFromRawValue() {
        XCTAssertEqual(VerticalDirection(rawValue: 0), .defaultOrder)
        XCTAssertEqual(VerticalDirection(rawValue: 1), .topGoesFirst)
        XCTAssertEqual(VerticalDirection(rawValue: 2), .bottomGoesFirst)
        XCTAssertNil(VerticalDirection(rawValue: 99))
    }
}
