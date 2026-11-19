//
//  LegacyMigrationsTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class LegacyMigrationsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    /// The keys that `perform()` migrates *to*; must match `resetMigratedKeys()`.
    private let migratedKeys: Set<String> = [
        "visibleSpacesMode", "restartNumberingByDisplay", "horizontalDirection",
        "useVariableWidth", "decorationActive", "decorationInactive",
        "iconSize", "iconText", "rowLayout", "showFullscreenSpaces",
        "switchingMode"
    ]

    override func setUp() {
        super.setUp()
        suiteName = "LegacyMigrationsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// Only the keys stored in this test's own suite (excludes the global domain).
    private var storedKeys: Set<String> {
        Set((defaults.persistentDomain(forName: suiteName) ?? [:]).keys)
    }

    private func migrate() {
        LegacyMigrations.perform(defaults: defaults)
    }

    // MARK: - Obsolete keys

    func testRemovesObsoleteKeys() {
        defaults.set(Data([1, 2, 3]), forKey: "spaceNameCache")
        defaults.set(true, forKey: "allowChaining")
        defaults.set(true, forKey: "navigateAnywhere")

        migrate()

        XCTAssertNil(defaults.object(forKey: "spaceNameCache"))
        XCTAssertNil(defaults.object(forKey: "allowChaining"))
        XCTAssertNil(defaults.object(forKey: "navigateAnywhere"))
    }

    // MARK: - spaceByDesktopID → spaceLabel

    func testSpaceByDesktopID_isRenamedToSpaceLabel() throws {
        let old: [String: [String: Any]] = [
            "101": ["spaceName": "HOME", "spaceByDesktopID": "1"],
            "102": ["spaceName": "WORK", "spaceByDesktopID": "2"]
        ]
        defaults.set(
            try PropertyListSerialization.data(fromPropertyList: old, format: .binary, options: 0),
            forKey: "spaceNames")

        migrate()

        let data = try XCTUnwrap(defaults.data(forKey: "spaceNames"))
        let migrated = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: [String: Any]])
        XCTAssertEqual(migrated["101"]?["spaceLabel"] as? String, "1")
        XCTAssertEqual(migrated["102"]?["spaceLabel"] as? String, "2")
        XCTAssertNil(migrated["101"]?["spaceByDesktopID"])
        XCTAssertNil(migrated["102"]?["spaceByDesktopID"])
        XCTAssertEqual(migrated["101"]?["spaceName"] as? String, "HOME")
    }

    func testSpaceNamesWithoutLegacyKey_areLeftUntouched() throws {
        let current: [String: [String: Any]] = ["101": ["spaceName": "HOME", "spaceLabel": "1"]]
        let data = try PropertyListSerialization.data(fromPropertyList: current, format: .xml, options: 0)
        defaults.set(data, forKey: "spaceNames")

        migrate()

        XCTAssertEqual(defaults.data(forKey: "spaceNames"), data)
    }

    // MARK: - hideInactiveSpaces → visibleSpacesMode

    func testHideInactiveSpacesTrue_becomesCurrentOnly() {
        defaults.set(true, forKey: "hideInactiveSpaces")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "visibleSpacesMode"), VisibleSpacesMode.currentOnly.rawValue)
        XCTAssertNil(defaults.object(forKey: "hideInactiveSpaces"))
    }

    func testHideInactiveSpacesFalse_becomesAll() {
        defaults.set(false, forKey: "hideInactiveSpaces")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "visibleSpacesMode") as? Int, VisibleSpacesMode.all.rawValue)
        XCTAssertNil(defaults.object(forKey: "hideInactiveSpaces"))
    }

    func testExistingVisibleSpacesMode_isKept_andLegacyKeyRemoved() {
        defaults.set(VisibleSpacesMode.neighbors.rawValue, forKey: "visibleSpacesMode")
        defaults.set(true, forKey: "hideInactiveSpaces")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "visibleSpacesMode"), VisibleSpacesMode.neighbors.rawValue)
        XCTAssertNil(defaults.object(forKey: "hideInactiveSpaces"))
    }

    // MARK: - restartNumberingByDesktop → restartNumberingByDisplay

    func testRestartNumberingByDesktop_isRenamed() {
        defaults.set(true, forKey: "restartNumberingByDesktop")
        migrate()
        XCTAssertTrue(defaults.bool(forKey: "restartNumberingByDisplay"))
        XCTAssertNil(defaults.object(forKey: "restartNumberingByDesktop"))
    }

    // MARK: - reverseDisplayOrder → horizontalDirection

    func testReverseDisplayOrderTrue_becomesReverseOrder() {
        defaults.set(true, forKey: "reverseDisplayOrder")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "horizontalDirection"), HorizontalDirection.reverseOrder.rawValue)
        XCTAssertNil(defaults.object(forKey: "reverseDisplayOrder"))
    }

    func testReverseDisplayOrderMissing_becomesDefaultOrder() {
        migrate()
        XCTAssertEqual(
            defaults.object(forKey: "horizontalDirection") as? Int, HorizontalDirection.defaultOrder.rawValue)
    }

    // MARK: - useMinIconWidth → useVariableWidth (inverted)

    func testUseMinIconWidthTrue_becomesFixedWidth() {
        defaults.set(true, forKey: "useMinIconWidth")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "useVariableWidth") as? Bool, false)
        XCTAssertNil(defaults.object(forKey: "useMinIconWidth"))
    }

    func testUseMinIconWidthFalse_becomesVariableWidth() {
        defaults.set(false, forKey: "useMinIconWidth")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "useVariableWidth") as? Bool, true)
    }

    func testUseMinIconWidthMissing_leavesVariableWidthUnset() {
        migrate()
        XCTAssertNil(defaults.object(forKey: "useVariableWidth"))
    }

    // MARK: - displayStyle / inactiveStyle → decoration + iconText

    func testDisplayStyleText_becomesNoDecorationWithNumbers() {
        defaults.set(1, forKey: "displayStyle")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "decorationActive") as? Int, IconStyle.noDecoration.rawValue)
        XCTAssertEqual(defaults.object(forKey: "decorationInactive") as? Int, IconStyle.noDecoration.rawValue)
        XCTAssertEqual(defaults.integer(forKey: "iconText"), IconText.numbers.rawValue)
    }

    func testInactiveStyleBordered_becomesFilledActiveAndBorderedInactive() {
        defaults.set(0, forKey: "displayStyle")
        defaults.set(0, forKey: "inactiveStyle")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "decorationActive"), IconStyle.filledRounded.rawValue)
        XCTAssertEqual(defaults.integer(forKey: "decorationInactive"), IconStyle.borderedRounded.rawValue)
        XCTAssertNil(defaults.object(forKey: "inactiveStyle"))
    }

    func testInactiveStyleFilled_becomesFilledForBoth() {
        defaults.set(0, forKey: "displayStyle")
        defaults.set(1, forKey: "inactiveStyle")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "decorationActive"), IconStyle.filledRounded.rawValue)
        XCTAssertEqual(defaults.integer(forKey: "decorationInactive"), IconStyle.filledRounded.rawValue)
    }

    func testDisplayStyle_isCopiedToIconText_andRemoved() {
        defaults.set(IconText.names.rawValue, forKey: "displayStyle")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "iconText"), IconText.names.rawValue)
        XCTAssertNil(defaults.object(forKey: "displayStyle"))
    }

    func testExistingDecoration_isNotOverwritten() {
        defaults.set(IconStyle.filledPill.rawValue, forKey: "decorationActive")
        defaults.set(1, forKey: "displayStyle")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "decorationActive"), IconStyle.filledPill.rawValue)
    }

    // MARK: - dualRows / dualRowFillOrder → rowLayout

    func testDualRowsFalse_becomesSingleRow() {
        defaults.set(false, forKey: "dualRows")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "rowLayout") as? Int, RowLayout.singleRow.rawValue)
        XCTAssertNil(defaults.object(forKey: "dualRows"))
    }

    func testDualRowsWithFillOrderByRow_becomesTwoRowsByRow() {
        defaults.set(true, forKey: "dualRows")
        defaults.set(1, forKey: "dualRowFillOrder")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "rowLayout"), RowLayout.twoRowsByRow.rawValue)
        XCTAssertNil(defaults.object(forKey: "dualRows"))
        XCTAssertNil(defaults.object(forKey: "dualRowFillOrder"))
    }

    func testDualRowsWithFillOrderByColumn_becomesTwoRowsByColumn() {
        defaults.set(true, forKey: "dualRows")
        defaults.set(0, forKey: "dualRowFillOrder")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "rowLayout"), RowLayout.twoRowsByColumn.rawValue)
    }

    func testDualRowsMissing_leavesRowLayoutUnset() {
        migrate()
        XCTAssertNil(defaults.object(forKey: "rowLayout"))
    }

    // MARK: - layoutMode → rowLayout + iconSize

    /// layoutMode 0 was the old two-row mode. The first migration turns it into
    /// layoutMode 1 (compact) + two rows; the later one turns layoutMode 1 into iconSize.
    func testLayoutModeZero_becomesCompactTwoRows() {
        defaults.set(0, forKey: "layoutMode")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "rowLayout"), RowLayout.twoRowsByColumn.rawValue)
        XCTAssertEqual(defaults.integer(forKey: "iconSize"), IconSize.compact.rawValue)
        XCTAssertNil(defaults.object(forKey: "layoutMode"))
    }

    func testLayoutModeZero_winsOverDualRows() {
        defaults.set(0, forKey: "layoutMode")
        defaults.set(false, forKey: "dualRows")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "rowLayout"), RowLayout.twoRowsByColumn.rawValue)
    }

    func testLayoutModeNarrow_isRenumbered() {
        defaults.set(5, forKey: "layoutMode")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "iconSize") as? Int, IconSize.narrow.rawValue)
        XCTAssertNil(defaults.object(forKey: "layoutMode"))
    }

    func testLayoutModeEnormous_isRenumbered() {
        defaults.set(6, forKey: "layoutMode")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "iconSize"), IconSize.enormous.rawValue)
    }

    func testLayoutModeCompactToExtraLarge_keepTheirNumbers() {
        let unchanged: [IconSize] = [.compact, .medium, .large, .extraLarge]
        for size in unchanged {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(size.rawValue, forKey: "layoutMode")
            migrate()
            XCTAssertEqual(defaults.integer(forKey: "iconSize"), size.rawValue, "layoutMode \(size.rawValue)")
        }
    }

    func testExistingIconSize_isNotOverwritten() {
        defaults.set(IconSize.extraLarge.rawValue, forKey: "iconSize")
        defaults.set(6, forKey: "layoutMode")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "iconSize"), IconSize.extraLarge.rawValue)
    }

    // MARK: - hideFullscreenSpaces → showFullscreenSpaces (inverted)

    func testHideFullscreenSpacesTrue_becomesHidden() {
        defaults.set(true, forKey: "hideFullscreenSpaces")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "showFullscreenSpaces") as? Bool, false)
        XCTAssertNil(defaults.object(forKey: "hideFullscreenSpaces"))
    }

    func testHideFullscreenSpacesFalse_becomesShown() {
        defaults.set(false, forKey: "hideFullscreenSpaces")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "showFullscreenSpaces") as? Bool, true)
    }

    // MARK: - useGestureSwitching → switchingMode

    func testUseGestureSwitchingTrue_becomesInstant() {
        defaults.set(true, forKey: "useGestureSwitching")
        migrate()
        XCTAssertEqual(defaults.integer(forKey: "switchingMode"), SwitchingMode.instant.rawValue)
        XCTAssertNil(defaults.object(forKey: "useGestureSwitching"))
    }

    func testUseGestureSwitchingFalse_becomesSmooth() {
        defaults.set(false, forKey: "useGestureSwitching")
        migrate()
        XCTAssertEqual(defaults.object(forKey: "switchingMode") as? Int, SwitchingMode.smooth.rawValue)
    }

    // MARK: - Whole run

    /// Sets every legacy key that a migration reads, without any of the new keys.
    private func setAllLegacyKeys() {
        defaults.set(true, forKey: "hideInactiveSpaces")
        defaults.set(true, forKey: "restartNumberingByDesktop")
        defaults.set(true, forKey: "reverseDisplayOrder")
        defaults.set(true, forKey: "useMinIconWidth")
        defaults.set(IconText.names.rawValue, forKey: "displayStyle")
        defaults.set(0, forKey: "inactiveStyle")
        defaults.set(true, forKey: "dualRows")
        defaults.set(1, forKey: "dualRowFillOrder")
        defaults.set(IconSize.large.rawValue, forKey: "layoutMode")
        defaults.set(true, forKey: "hideFullscreenSpaces")
        defaults.set(true, forKey: "useGestureSwitching")
    }

    func testFullMigration_leavesOnlyMigratedKeys() {
        setAllLegacyKeys()
        migrate()
        XCTAssertEqual(storedKeys, migratedKeys)
    }

    func testPerform_isIdempotent() {
        setAllLegacyKeys()
        migrate()
        let afterFirstRun = defaults.persistentDomain(forName: suiteName) as NSDictionary?
        migrate()
        let afterSecondRun = defaults.persistentDomain(forName: suiteName) as NSDictionary?
        XCTAssertEqual(afterFirstRun, afterSecondRun)
    }

    // MARK: - resetMigratedKeys

    /// Guards the "must be kept in sync with perform()" rule: everything a full
    /// migration writes must be removed again by resetMigratedKeys().
    func testResetMigratedKeys_removesEverythingPerformWrites() {
        setAllLegacyKeys()
        migrate()
        LegacyMigrations.resetMigratedKeys(defaults: defaults)
        XCTAssertEqual(storedKeys, [])
    }

    func testResetMigratedKeys_keepsUnrelatedKeys() {
        defaults.set("kept", forKey: "someOtherSetting")
        defaults.set(IconSize.large.rawValue, forKey: "iconSize")
        LegacyMigrations.resetMigratedKeys(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "someOtherSetting"), "kept")
        XCTAssertNil(defaults.object(forKey: "iconSize"))
    }

    /// The restore flow: a backup with old-format keys is loaded over current settings.
    /// Without the reset, the existing new keys would block the migrations.
    func testRestoreFlow_backupLegacyKeysWinAfterReset() {
        defaults.set(SwitchingMode.fast.rawValue, forKey: "switchingMode")
        defaults.set(true, forKey: "useGestureSwitching")

        LegacyMigrations.resetMigratedKeys(defaults: defaults)
        migrate()

        XCTAssertEqual(defaults.integer(forKey: "switchingMode"), SwitchingMode.instant.rawValue)
    }
}
