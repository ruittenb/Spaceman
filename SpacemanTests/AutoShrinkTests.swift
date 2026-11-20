//
//  AutoShrinkTests.swift
//  SpacemanTests
//
//  Tests for fit-to-width: which triggers retry the user's size, how the
//  icon size steps down when the menu bar has no room (AppDelegate.fitIcon),
//  and how the backstop reacts when the item is hidden (evictionResponse).
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

    // MARK: - AppDelegate.fitIcon

    /// Fake icon widths: every size step is 20 points wide.
    private let fakeWidths: [IconSize: CGFloat] = [
        .narrow: 40, .compact: 60, .medium: 80, .large: 100, .extraLarge: 120, .enormous: 140
    ]

    /// Runs fitIcon with fake icons and records which sizes were rendered.
    private func fit(
        userSize: IconSize, fittedSize: IconSize? = nil, budget: CGFloat?, twoRows: Bool = false
    ) -> (size: IconSize, width: CGFloat, rendered: [IconSize]) {
        var rendered: [IconSize] = []
        let result = AppDelegate.fitIcon(
            userSize: userSize, fittedSize: fittedSize, budget: budget, twoRows: twoRows
        ) { size in
            rendered.append(size)
            return NSImage(size: NSSize(width: self.fakeWidths[size] ?? 0, height: 22))
        }
        return (result.size, result.icon.size.width, rendered)
    }

    func testFitIcon_fitsAtUserSize_rendersOnce() {
        let result = fit(userSize: .large, budget: 150)
        XCTAssertEqual(result.size, .large)
        XCTAssertEqual(result.rendered, [.large])
    }

    func testFitIcon_widthEqualToBudget_fits() {
        let result = fit(userSize: .medium, budget: 80)
        XCTAssertEqual(result.size, .medium)
    }

    func testFitIcon_tooWide_stepsDownUntilItFits() {
        let result = fit(userSize: .large, budget: 85)
        XCTAssertEqual(result.size, .medium)
        XCTAssertEqual(result.width, 80)
        XCTAssertEqual(result.rendered, [.large, .medium])
    }

    func testFitIcon_nothingFits_stopsAtSmallestSize() {
        let result = fit(userSize: .medium, budget: 30)
        XCTAssertEqual(result.size, .narrow)
        XCTAssertEqual(result.rendered, [.medium, .compact, .narrow])
    }

    func testFitIcon_twoRows_stopsAtSmallestTwoRowSize() {
        // narrow has no two-row entry, so compact is the floor
        let result = fit(userSize: .medium, budget: 30, twoRows: true)
        XCTAssertEqual(result.size, .compact)
        XCTAssertFalse(result.rendered.contains(.narrow))
    }

    func testFitIcon_withBudget_startsFromUserSizeSoTheIconGrowsBack() {
        let result = fit(userSize: .large, fittedSize: .compact, budget: 150)
        XCTAssertEqual(result.size, .large)
    }

    func testFitIcon_withoutBudget_keepsBackstopSize() {
        let result = fit(userSize: .large, fittedSize: .compact, budget: nil)
        XCTAssertEqual(result.size, .compact)
        XCTAssertEqual(result.rendered, [.compact])
    }

    func testFitIcon_withoutBudgetOrBackstop_usesUserSizeWithoutShrinking() {
        let result = fit(userSize: .enormous, budget: nil)
        XCTAssertEqual(result.size, .enormous)
        XCTAssertEqual(result.rendered, [.enormous])
    }

    // MARK: - AppDelegate.evictionResponse

    func testEviction_noBudget_tightensBelowRenderedWidth() {
        let response = AppDelegate.evictionResponse(
            budget: nil, lastIconWidth: 100, fittedSize: nil, userSize: .large, twoRows: false)
        XCTAssertEqual(response, .tightenBudget(99))
    }

    func testEviction_budgetAboveRenderedWidth_tightensBelowRenderedWidth() {
        let response = AppDelegate.evictionResponse(
            budget: 200, lastIconWidth: 100, fittedSize: nil, userSize: .large, twoRows: false)
        XCTAssertEqual(response, .tightenBudget(99))
    }

    func testEviction_alreadyBudgetedBelow_stepsDownFromUserSize() {
        let response = AppDelegate.evictionResponse(
            budget: 99, lastIconWidth: 100, fittedSize: nil, userSize: .large, twoRows: false)
        XCTAssertEqual(response, .stepDown(.medium))
    }

    func testEviction_alreadyBudgetedBelow_stepsDownFromFittedSize() {
        let response = AppDelegate.evictionResponse(
            budget: 50, lastIconWidth: 80, fittedSize: .medium, userSize: .large, twoRows: false)
        XCTAssertEqual(response, .stepDown(.compact))
    }

    func testEviction_atSmallestSize_givesUp() {
        let singleRow = AppDelegate.evictionResponse(
            budget: 30, lastIconWidth: 40, fittedSize: .narrow, userSize: .large, twoRows: false)
        XCTAssertEqual(singleRow, .giveUp)
        let twoRows = AppDelegate.evictionResponse(
            budget: 50, lastIconWidth: 60, fittedSize: .compact, userSize: .large, twoRows: true)
        XCTAssertEqual(twoRows, .giveUp)
    }
}
