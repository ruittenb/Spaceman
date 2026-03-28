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

    // MARK: - IconStyle

    func testIconStyleRawValues() {
        XCTAssertEqual(IconStyle.noDecoration.rawValue, 0)
        XCTAssertEqual(IconStyle.borderedRectangular.rawValue, 1)
        XCTAssertEqual(IconStyle.borderedRounded.rawValue, 2)
        XCTAssertEqual(IconStyle.borderedPill.rawValue, 3)
        XCTAssertEqual(IconStyle.filledRectangular.rawValue, 4)
        XCTAssertEqual(IconStyle.filledRounded.rawValue, 5)
        XCTAssertEqual(IconStyle.filledPill.rawValue, 6)
    }

    func testIconStyleAllCases() {
        XCTAssertEqual(IconStyle.allCases.count, 7)
    }

    func testIconStyleInitFromRawValue() {
        XCTAssertEqual(IconStyle(rawValue: 0), .noDecoration)
        XCTAssertEqual(IconStyle(rawValue: 1), .borderedRectangular)
        XCTAssertEqual(IconStyle(rawValue: 2), .borderedRounded)
        XCTAssertEqual(IconStyle(rawValue: 3), .borderedPill)
        XCTAssertEqual(IconStyle(rawValue: 4), .filledRectangular)
        XCTAssertEqual(IconStyle(rawValue: 5), .filledRounded)
        XCTAssertEqual(IconStyle(rawValue: 6), .filledPill)
        XCTAssertNil(IconStyle(rawValue: 99))
    }

    func testIconStyleFullscreenVariant() {
        // Bare text stays bare text
        XCTAssertEqual(IconStyle.noDecoration.fullscreenVariant, .noDecoration)
        // Rectangular becomes pill (and vice versa), preserving fill style
        XCTAssertEqual(IconStyle.borderedRectangular.fullscreenVariant, .borderedPill)
        XCTAssertEqual(IconStyle.filledRectangular.fullscreenVariant, .filledPill)
        XCTAssertEqual(IconStyle.borderedPill.fullscreenVariant, .borderedRectangular)
        XCTAssertEqual(IconStyle.filledPill.fullscreenVariant, .filledRectangular)
        // Rounded becomes rectangular
        XCTAssertEqual(IconStyle.borderedRounded.fullscreenVariant, .borderedRectangular)
        XCTAssertEqual(IconStyle.filledRounded.fullscreenVariant, .filledRectangular)
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
        XCTAssertEqual(LayoutMode.allCases.count, 7)
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
