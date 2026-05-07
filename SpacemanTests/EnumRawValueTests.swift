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

    // MARK: - IconText

    func testIconTextRawValues() {
        XCTAssertEqual(IconText.noText.rawValue, 0)
        XCTAssertEqual(IconText.numbers.rawValue, 2)
        XCTAssertEqual(IconText.names.rawValue, 3)
        XCTAssertEqual(IconText.numbersAndNames.rawValue, 4)
    }

    func testIconTextAllCases() {
        XCTAssertEqual(IconText.allCases.count, 4)
    }

    func testIconTextInitFromRawValue() {
        XCTAssertEqual(IconText(rawValue: 0), .noText)
        XCTAssertNil(IconText(rawValue: 1)) // was bare numbers, now migrated away
        XCTAssertEqual(IconText(rawValue: 2), .numbers)
        XCTAssertEqual(IconText(rawValue: 3), .names)
        XCTAssertEqual(IconText(rawValue: 4), .numbersAndNames)
        XCTAssertNil(IconText(rawValue: 99))
    }

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

    // MARK: - IconSize

    func testIconSizeRawValues() {
        XCTAssertEqual(IconSize.narrow.rawValue, 0)
        XCTAssertEqual(IconSize.compact.rawValue, 1)
        XCTAssertEqual(IconSize.medium.rawValue, 2)
        XCTAssertEqual(IconSize.large.rawValue, 3)
        XCTAssertEqual(IconSize.extraLarge.rawValue, 4)
        XCTAssertEqual(IconSize.enormous.rawValue, 5)
    }

    func testIconSizeAllCases() {
        XCTAssertEqual(IconSize.allCases.count, 6)
    }

    func testIconSizeInitFromRawValue() {
        XCTAssertEqual(IconSize(rawValue: 0), .narrow)
        XCTAssertEqual(IconSize(rawValue: 1), .compact)
        XCTAssertEqual(IconSize(rawValue: 2), .medium)
        XCTAssertEqual(IconSize(rawValue: 3), .large)
        XCTAssertEqual(IconSize(rawValue: 4), .extraLarge)
        XCTAssertEqual(IconSize(rawValue: 5), .enormous)
        XCTAssertNil(IconSize(rawValue: 6))
        XCTAssertNil(IconSize(rawValue: 99))
    }

    // MARK: - RowLayout

    func testRowLayoutRawValues() {
        XCTAssertEqual(RowLayout.singleRow.rawValue, 0)
        XCTAssertEqual(RowLayout.twoRowsByRow.rawValue, 1)
        XCTAssertEqual(RowLayout.twoRowsByColumn.rawValue, 2)
    }

    func testRowLayoutAllCases() {
        XCTAssertEqual(RowLayout.allCases.count, 3)
    }

    func testRowLayoutInitFromRawValue() {
        XCTAssertEqual(RowLayout(rawValue: 0), .singleRow)
        XCTAssertEqual(RowLayout(rawValue: 1), .twoRowsByRow)
        XCTAssertEqual(RowLayout(rawValue: 2), .twoRowsByColumn)
        XCTAssertNil(RowLayout(rawValue: 99))
    }

    func testRowLayoutIsTwoRows() {
        XCTAssertFalse(RowLayout.singleRow.isTwoRows)
        XCTAssertTrue(RowLayout.twoRowsByColumn.isTwoRows)
        XCTAssertTrue(RowLayout.twoRowsByRow.isTwoRows)
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

    // MARK: - IconFill

    func testIconFillRawValues() {
        XCTAssertEqual(IconFill.bordered.rawValue, 0)
        XCTAssertEqual(IconFill.filled.rawValue, 1)
    }

    func testIconFillAllCases() {
        XCTAssertEqual(IconFill.allCases.count, 2)
    }

    func testIconFillInitFromRawValue() {
        XCTAssertEqual(IconFill(rawValue: 0), .bordered)
        XCTAssertEqual(IconFill(rawValue: 1), .filled)
        XCTAssertNil(IconFill(rawValue: 99))
    }

    // MARK: - IconShape

    func testIconShapeRawValues() {
        XCTAssertEqual(IconShape.noDecoration.rawValue, 0)
        XCTAssertEqual(IconShape.rectangular.rawValue, 1)
        XCTAssertEqual(IconShape.rounded.rawValue, 2)
        XCTAssertEqual(IconShape.pill.rawValue, 3)
    }

    func testIconShapeAllCases() {
        XCTAssertEqual(IconShape.allCases.count, 4)
    }

    func testIconShapeInitFromRawValue() {
        XCTAssertEqual(IconShape(rawValue: 0), .noDecoration)
        XCTAssertEqual(IconShape(rawValue: 1), .rectangular)
        XCTAssertEqual(IconShape(rawValue: 2), .rounded)
        XCTAssertEqual(IconShape(rawValue: 3), .pill)
        XCTAssertNil(IconShape(rawValue: 99))
    }

    // MARK: - SpaceDisplayMode

    func testSpaceDisplayModeRawValues() {
        XCTAssertEqual(SpaceDisplayMode.list.rawValue, 0)
        XCTAssertEqual(SpaceDisplayMode.grid.rawValue, 1)
    }

    func testSpaceDisplayModeAllCases() {
        XCTAssertEqual(SpaceDisplayMode.allCases.count, 2)
    }

    func testSpaceDisplayModeInitFromRawValue() {
        XCTAssertEqual(SpaceDisplayMode(rawValue: 0), .list)
        XCTAssertEqual(SpaceDisplayMode(rawValue: 1), .grid)
        XCTAssertNil(SpaceDisplayMode(rawValue: 99))
    }

    // MARK: - FontDesign

    func testFontDesignRawValues() {
        XCTAssertEqual(FontDesign.sans.rawValue, 0)
        XCTAssertEqual(FontDesign.serif.rawValue, 1)
        XCTAssertEqual(FontDesign.monospaced.rawValue, 2)
        XCTAssertEqual(FontDesign.rounded.rawValue, 3)
    }

    func testFontDesignAllCases() {
        XCTAssertEqual(FontDesign.allCases.count, 4)
    }

    func testFontDesignInitFromRawValue() {
        XCTAssertEqual(FontDesign(rawValue: 0), .sans)
        XCTAssertEqual(FontDesign(rawValue: 1), .serif)
        XCTAssertEqual(FontDesign(rawValue: 2), .monospaced)
        XCTAssertEqual(FontDesign(rawValue: 3), .rounded)
        XCTAssertNil(FontDesign(rawValue: 99))
    }
}
