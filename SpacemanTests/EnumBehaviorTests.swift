//
//  EnumBehaviorTests.swift
//  SpacemanTests
//
//  Created by Claude Code on 03/04/2026.
//
//  Tests for computed properties and behavioral logic on enums.
//

import XCTest
@testable import Spaceman

final class EnumBehaviorTests: XCTestCase {

    // MARK: - IconSize.larger / .smaller

    func testIconSizeLarger() {
        XCTAssertEqual(IconSize.narrow.larger, .compact)
        XCTAssertEqual(IconSize.compact.larger, .medium)
        XCTAssertEqual(IconSize.medium.larger, .large)
        XCTAssertEqual(IconSize.large.larger, .extraLarge)
        XCTAssertEqual(IconSize.extraLarge.larger, .enormous)
        XCTAssertNil(IconSize.enormous.larger)
    }

    func testIconSizeSmaller() {
        XCTAssertNil(IconSize.narrow.smaller)
        XCTAssertEqual(IconSize.compact.smaller, .narrow)
        XCTAssertEqual(IconSize.medium.smaller, .compact)
        XCTAssertEqual(IconSize.large.smaller, .medium)
        XCTAssertEqual(IconSize.extraLarge.smaller, .large)
        XCTAssertEqual(IconSize.enormous.smaller, .extraLarge)
    }

    // MARK: - IconStyle boolean properties

    func testIconStyleIsNoDecoration() {
        XCTAssertTrue(IconStyle.noDecoration.isNoDecoration)
        for style in IconStyle.allCases where style != .noDecoration {
            XCTAssertFalse(style.isNoDecoration, "\(style) should not be noDecoration")
        }
    }

    func testIconStyleIsFilled() {
        let filled: Set<IconStyle> = [.filledRectangular, .filledRounded, .filledPill]
        for style in IconStyle.allCases {
            XCTAssertEqual(style.isFilled, filled.contains(style), "\(style).isFilled")
        }
    }

    func testIconStyleIsBordered() {
        let bordered: Set<IconStyle> = [.borderedRectangular, .borderedRounded, .borderedPill]
        for style in IconStyle.allCases {
            XCTAssertEqual(style.isBordered, bordered.contains(style), "\(style).isBordered")
        }
    }

    func testIconStyleFilledAndBorderedAreMutuallyExclusive() {
        for style in IconStyle.allCases {
            XCTAssertFalse(style.isFilled && style.isBordered, "\(style) is both filled and bordered")
        }
    }

    // MARK: - IconStyle.shape / .fill

    func testIconStyleShape() {
        XCTAssertEqual(IconStyle.noDecoration.shape, .noDecoration)
        XCTAssertEqual(IconStyle.borderedRectangular.shape, .rectangular)
        XCTAssertEqual(IconStyle.filledRectangular.shape, .rectangular)
        XCTAssertEqual(IconStyle.borderedRounded.shape, .rounded)
        XCTAssertEqual(IconStyle.filledRounded.shape, .rounded)
        XCTAssertEqual(IconStyle.borderedPill.shape, .pill)
        XCTAssertEqual(IconStyle.filledPill.shape, .pill)
    }

    func testIconStyleFill() {
        XCTAssertEqual(IconStyle.noDecoration.fill, .bordered)
        XCTAssertEqual(IconStyle.borderedRectangular.fill, .bordered)
        XCTAssertEqual(IconStyle.borderedRounded.fill, .bordered)
        XCTAssertEqual(IconStyle.borderedPill.fill, .bordered)
        XCTAssertEqual(IconStyle.filledRectangular.fill, .filled)
        XCTAssertEqual(IconStyle.filledRounded.fill, .filled)
        XCTAssertEqual(IconStyle.filledPill.fill, .filled)
    }

    // MARK: - IconStyle.withShape / .withFill

    func testIconStyleWithShape() {
        // Bordered styles preserve border
        XCTAssertEqual(IconStyle.borderedRounded.withShape(.rectangular), .borderedRectangular)
        XCTAssertEqual(IconStyle.borderedRounded.withShape(.pill), .borderedPill)
        // Filled styles preserve fill
        XCTAssertEqual(IconStyle.filledRounded.withShape(.rectangular), .filledRectangular)
        XCTAssertEqual(IconStyle.filledRounded.withShape(.pill), .filledPill)
        // noDecoration shape → noDecoration
        XCTAssertEqual(IconStyle.filledRounded.withShape(.noDecoration), .noDecoration)
        // noDecoration source defaults to bordered
        XCTAssertEqual(IconStyle.noDecoration.withShape(.rounded), .borderedRounded)
    }

    func testIconStyleWithFill() {
        // Change fill, preserve shape
        XCTAssertEqual(IconStyle.borderedRounded.withFill(.filled), .filledRounded)
        XCTAssertEqual(IconStyle.filledPill.withFill(.bordered), .borderedPill)
        // noDecoration source defaults to rectangular
        XCTAssertEqual(IconStyle.noDecoration.withFill(.filled), .filledRectangular)
        XCTAssertEqual(IconStyle.noDecoration.withFill(.bordered), .borderedRectangular)
    }

    func testIconStyleWithShapeRoundTrip() {
        // Changing shape then back should return to original
        for style in IconStyle.allCases where !style.isNoDecoration {
            let changed = style.withShape(.pill)
            let restored = changed.withShape(style.shape)
            XCTAssertEqual(restored, style, "round-trip failed for \(style)")
        }
    }

    func testIconStyleWithFillRoundTrip() {
        // Changing fill then back should return to original
        for style in IconStyle.allCases where !style.isNoDecoration {
            let changed = style.withFill(style.isFilled ? .bordered : .filled)
            let restored = changed.withFill(style.fill)
            XCTAssertEqual(restored, style, "round-trip failed for \(style)")
        }
    }

    // MARK: - IconStyle.cornerRadius

    func testIconStyleCornerRadius() {
        let rect = NSRect(x: 0, y: 0, width: 20, height: 10)
        // Rectangular and noDecoration → 0
        XCTAssertEqual(IconStyle.noDecoration.cornerRadius(for: rect), 0)
        XCTAssertEqual(IconStyle.borderedRectangular.cornerRadius(for: rect), 0)
        XCTAssertEqual(IconStyle.filledRectangular.cornerRadius(for: rect), 0)
        // Rounded → 20% of height
        XCTAssertEqual(IconStyle.borderedRounded.cornerRadius(for: rect), 2.0)
        XCTAssertEqual(IconStyle.filledRounded.cornerRadius(for: rect), 2.0)
        // Pill → half height
        XCTAssertEqual(IconStyle.borderedPill.cornerRadius(for: rect), 5.0)
        XCTAssertEqual(IconStyle.filledPill.cornerRadius(for: rect), 5.0)
    }

    // MARK: - FontDesign.systemDesign

    func testFontDesignSystemDesign() {
        XCTAssertEqual(FontDesign.sans.systemDesign, .default)
        XCTAssertEqual(FontDesign.serif.systemDesign, .serif)
        XCTAssertEqual(FontDesign.monospaced.systemDesign, .monospaced)
        XCTAssertEqual(FontDesign.rounded.systemDesign, .rounded)
    }

    // MARK: - Constants.nearestTwoRowSize

    func testNearestTwoRowSizeMapping() {
        // narrow and compact both map to compact
        let narrowSize = Constants.nearestTwoRowSize(for: .narrow)
        let compactSize = Constants.nearestTwoRowSize(for: .compact)
        XCTAssertEqual(narrowSize.GAP_WIDTH_SPACES, compactSize.GAP_WIDTH_SPACES)

        // medium maps to medium (different from compact)
        let mediumSize = Constants.nearestTwoRowSize(for: .medium)
        XCTAssertNotEqual(mediumSize.GAP_WIDTH_SPACES, compactSize.GAP_WIDTH_SPACES)

        // large, extraLarge, enormous all map to large
        let largeSize = Constants.nearestTwoRowSize(for: .large)
        let xlSize = Constants.nearestTwoRowSize(for: .extraLarge)
        let enormousSize = Constants.nearestTwoRowSize(for: .enormous)
        XCTAssertEqual(largeSize.GAP_WIDTH_SPACES, xlSize.GAP_WIDTH_SPACES)
        XCTAssertEqual(largeSize.GAP_WIDTH_SPACES, enormousSize.GAP_WIDTH_SPACES)
    }

    func testNearestTwoRowSizeHasRowGap() {
        // All two-row sizes should have a non-zero GAP_HEIGHT_ROWS
        for size in IconSize.allCases {
            let guiSize = Constants.nearestTwoRowSize(for: size)
            XCTAssertGreaterThan(guiSize.GAP_HEIGHT_ROWS, 0,
                                 "Two-row size for \(size) should have non-zero GAP_HEIGHT_ROWS")
        }
    }

    // MARK: - Constants.sizes completeness

    func testAllIconSizesHaveSingleRowEntry() {
        for size in IconSize.allCases {
            XCTAssertNotNil(Constants.sizes[size], "Missing single-row size for \(size)")
        }
    }

    func testSingleRowSizesHaveZeroRowGap() {
        for size in IconSize.allCases {
            let guiSize = Constants.sizes[size]!
            XCTAssertEqual(guiSize.GAP_HEIGHT_ROWS, 0,
                           "Single-row size for \(size) should have zero GAP_HEIGHT_ROWS")
        }
    }
}
