//
//  DisplayOrderingTests.swift
//  SpacemanTests
//
//  Created by Claude Code
//

import XCTest
@testable import Spaceman

final class DisplayOrderingTests: XCTestCase {

    // MARK: - Side-by-side displays

    func testSideBySideDisplays_DefaultOrder_LeftToRight() {
        // Left display (x=0) vs Right display (x=100)
        let leftCenter = CGPoint(x: 0, y: 50)
        let rightCenter = CGPoint(x: 100, y: 50)

        let result = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: false,
            verticalDirection: .bottomGoesFirst,
            horizontalDirection: .defaultOrder
        )

        XCTAssertTrue(result, "Left display should come before right display with default order")
    }

    func testSideBySideDisplays_ReverseOrder_RightToLeft() {
        // Left display (x=0) vs Right display (x=100)
        let leftCenter = CGPoint(x: 0, y: 50)
        let rightCenter = CGPoint(x: 100, y: 50)

        let result = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: false,
            verticalDirection: .bottomGoesFirst,
            horizontalDirection: .reverseOrder
        )

        XCTAssertFalse(result, "Right display should come before left display with reverse order")
    }

    func testSideBySideDisplays_VerticalDirectionDoesNotAffect() {
        // Test that changing vertical direction doesn't affect side-by-side displays
        let leftCenter = CGPoint(x: 0, y: 50)
        let rightCenter = CGPoint(x: 100, y: 50)

        // All vertical directions should give same result for horizontal displays
        let resultDefault = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: false,
            verticalDirection: .defaultOrder,
            horizontalDirection: .defaultOrder
        )

        let resultTopFirst = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: false,
            verticalDirection: .topGoesFirst,
            horizontalDirection: .defaultOrder
        )

        let resultBottomFirst = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: false,
            verticalDirection: .bottomGoesFirst,
            horizontalDirection: .defaultOrder
        )

        XCTAssertTrue(resultDefault, "Default vertical direction should not affect horizontal ordering")
        XCTAssertTrue(resultTopFirst, "Top-first vertical direction should not affect horizontal ordering")
        XCTAssertTrue(resultBottomFirst, "Bottom-first vertical direction should not affect horizontal ordering")
    }

    // MARK: - Vertically stacked displays

    func testVerticallyStackedDisplays_DefaultOrder_LeftToRight() {
        // Left display (x=0) vs Right display (x=100), stacked vertically
        let leftCenter = CGPoint(x: 0, y: 100)
        let rightCenter = CGPoint(x: 100, y: 0)

        let result = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: true,
            verticalDirection: .defaultOrder,
            horizontalDirection: .defaultOrder
        )

        XCTAssertTrue(result, "Left display should come before right display with default vertical order (LTR by X)")
    }

    func testVerticallyStackedDisplays_TopGoesFirst() {
        // Bottom display (y=0) vs Top display (y=100)
        // macOS coordinates: larger y = higher on screen
        let bottomCenter = CGPoint(x: 50, y: 0)
        let topCenter = CGPoint(x: 50, y: 100)

        let result = SpaceObserver.compareDisplayCenters(
            c1: bottomCenter,
            c2: topCenter,
            isVerticallyArranged: true,
            verticalDirection: .topGoesFirst,
            horizontalDirection: .defaultOrder
        )

        XCTAssertFalse(result, "Top display (higher y) should come before bottom display with top-goes-first")
    }

    func testVerticallyStackedDisplays_BottomGoesFirst() {
        // Bottom display (y=0) vs Top display (y=100)
        let bottomCenter = CGPoint(x: 50, y: 0)
        let topCenter = CGPoint(x: 50, y: 100)

        let result = SpaceObserver.compareDisplayCenters(
            c1: bottomCenter,
            c2: topCenter,
            isVerticallyArranged: true,
            verticalDirection: .bottomGoesFirst,
            horizontalDirection: .defaultOrder
        )

        XCTAssertTrue(result, "Bottom display (lower y) should come before top display with bottom-goes-first")
    }

    func testVerticallyStackedDisplays_HorizontalDirectionDoesNotAffect_DefaultVertical() {
        // Test that changing horizontal direction doesn't affect vertically stacked displays
        // when vertical direction is default
        let leftCenter = CGPoint(x: 0, y: 100)
        let rightCenter = CGPoint(x: 100, y: 0)

        let resultDefaultHorizontal = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: true,
            verticalDirection: .defaultOrder,
            horizontalDirection: .defaultOrder
        )

        let resultReverseHorizontal = SpaceObserver.compareDisplayCenters(
            c1: leftCenter,
            c2: rightCenter,
            isVerticallyArranged: true,
            verticalDirection: .defaultOrder,
            horizontalDirection: .reverseOrder
        )

        XCTAssertEqual(resultDefaultHorizontal, resultReverseHorizontal,
                      "Horizontal direction should not affect vertically stacked displays with default vertical order")
        XCTAssertTrue(resultDefaultHorizontal, "Should use LTR by X coordinate regardless of horizontal direction")
    }

    func testVerticallyStackedDisplays_HorizontalDirectionDoesNotAffect_TopFirst() {
        // Test that changing horizontal direction doesn't affect vertically stacked displays
        // when vertical direction is top-goes-first
        let bottomCenter = CGPoint(x: 50, y: 0)
        let topCenter = CGPoint(x: 50, y: 100)

        let resultDefaultHorizontal = SpaceObserver.compareDisplayCenters(
            c1: bottomCenter,
            c2: topCenter,
            isVerticallyArranged: true,
            verticalDirection: .topGoesFirst,
            horizontalDirection: .defaultOrder
        )

        let resultReverseHorizontal = SpaceObserver.compareDisplayCenters(
            c1: bottomCenter,
            c2: topCenter,
            isVerticallyArranged: true,
            verticalDirection: .topGoesFirst,
            horizontalDirection: .reverseOrder
        )

        XCTAssertEqual(resultDefaultHorizontal, resultReverseHorizontal,
                      "Horizontal direction should not affect vertically stacked displays with top-goes-first")
        XCTAssertFalse(resultDefaultHorizontal, "Top display should come first regardless of horizontal direction")
    }

    func testVerticallyStackedDisplays_HorizontalDirectionDoesNotAffect_BottomFirst() {
        // Test that changing horizontal direction doesn't affect vertically stacked displays
        // when vertical direction is bottom-goes-first
        let bottomCenter = CGPoint(x: 50, y: 0)
        let topCenter = CGPoint(x: 50, y: 100)

        let resultDefaultHorizontal = SpaceObserver.compareDisplayCenters(
            c1: bottomCenter,
            c2: topCenter,
            isVerticallyArranged: true,
            verticalDirection: .bottomGoesFirst,
            horizontalDirection: .defaultOrder
        )

        let resultReverseHorizontal = SpaceObserver.compareDisplayCenters(
            c1: bottomCenter,
            c2: topCenter,
            isVerticallyArranged: true,
            verticalDirection: .bottomGoesFirst,
            horizontalDirection: .reverseOrder
        )

        XCTAssertEqual(resultDefaultHorizontal, resultReverseHorizontal,
                      "Horizontal direction should not affect vertically stacked displays with bottom-goes-first")
        XCTAssertTrue(resultDefaultHorizontal, "Bottom display should come first regardless of horizontal direction")
    }

    // MARK: - Edge cases

    func testSamePosition() {
        // Displays at same position should maintain consistent ordering
        let center = CGPoint(x: 50, y: 50)

        let resultHorizontal = SpaceObserver.compareDisplayCenters(
            c1: center,
            c2: center,
            isVerticallyArranged: false,
            verticalDirection: .defaultOrder,
            horizontalDirection: .defaultOrder
        )

        let resultVertical = SpaceObserver.compareDisplayCenters(
            c1: center,
            c2: center,
            isVerticallyArranged: true,
            verticalDirection: .topGoesFirst,
            horizontalDirection: .defaultOrder
        )

        XCTAssertFalse(resultHorizontal, "Same position displays should return false for horizontal")
        XCTAssertFalse(resultVertical, "Same position displays should return false for vertical")
    }
}
