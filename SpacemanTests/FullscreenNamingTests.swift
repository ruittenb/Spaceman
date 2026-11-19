//
//  FullscreenNamingTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class FullscreenNamingTests: XCTestCase {

    // MARK: - shortName

    func testShortName_stripsVendorPrefix() {
        XCTAssertEqual(FullscreenNaming.shortName("Google Chrome"), "Chrome")
        XCTAssertEqual(FullscreenNaming.shortName("Mozilla Firefox"), "Firefox")
    }

    func testShortName_stripsVendorPrefixCaseInsensitively() {
        XCTAssertEqual(FullscreenNaming.shortName("MICROSOFT Word"), "Word")
    }

    func testShortName_stripsChannelSuffix() {
        XCTAssertEqual(FullscreenNaming.shortName("Firefox Nightly"), "Firefox")
    }

    func testShortName_stripsVendorAndChannel() {
        XCTAssertEqual(FullscreenNaming.shortName("Microsoft Edge Beta"), "Edge")
        XCTAssertEqual(FullscreenNaming.shortName("Google Chrome Canary"), "Chrome")
    }

    func testShortName_stripsStackedChannelSuffixes() {
        XCTAssertEqual(FullscreenNaming.shortName("Chrome Dev Beta"), "Chrome")
    }

    func testShortName_keepsSingleWord_evenIfVendorOrChannel() {
        XCTAssertEqual(FullscreenNaming.shortName("Safari"), "Safari")
        XCTAssertEqual(FullscreenNaming.shortName("Apple"), "Apple")
        XCTAssertEqual(FullscreenNaming.shortName("Beta"), "Beta")
    }

    func testShortName_keepsUpToTenCharacters() {
        XCTAssertEqual(FullscreenNaming.shortName("Logic Pro"), "Logic Pro")
        XCTAssertEqual(FullscreenNaming.shortName("Notes Plus"), "Notes Plus")
    }

    func testShortName_fallsBackToFirstWordAboveTenCharacters() {
        XCTAssertEqual(FullscreenNaming.shortName("Pixelmator Pro"), "Pixelmator")
        XCTAssertEqual(FullscreenNaming.shortName("Visual Studio Code Insiders"), "Visual")
        XCTAssertEqual(FullscreenNaming.shortName("Adobe Photoshop 2025"), "Photoshop")
    }

    // MARK: - displayName

    func testDisplayName_complete_capitalizesAppName() {
        XCTAssertEqual(FullscreenNaming.complete.displayName(forApp: "safari"), "Safari")
        XCTAssertEqual(FullscreenNaming.complete.displayName(forApp: "Google Chrome"), "Google Chrome")
    }

    func testDisplayName_short_usesShortName() {
        XCTAssertEqual(FullscreenNaming.short.displayName(forApp: "Microsoft Edge Beta"), "Edge")
    }

    func testDisplayName_withoutAppName_isFull() {
        XCTAssertEqual(FullscreenNaming.complete.displayName(forApp: nil), "FULL")
        XCTAssertEqual(FullscreenNaming.short.displayName(forApp: nil), "FULL")
    }

    func testDisplayName_none_isAlwaysEmpty() {
        XCTAssertEqual(FullscreenNaming.none.displayName(forApp: "Safari"), "")
        XCTAssertEqual(FullscreenNaming.none.displayName(forApp: nil), "")
    }

    // MARK: - isAutoName

    func testIsAutoName_missingOrEmptyName_isAuto() {
        XCTAssertTrue(FullscreenNaming.isAutoName(nil, appName: "Safari"))
        XCTAssertTrue(FullscreenNaming.isAutoName("", appName: "Safari"))
        XCTAssertTrue(FullscreenNaming.isAutoName(nil, appName: nil))
    }

    func testIsAutoName_matchesAppNameCaseInsensitively() {
        XCTAssertTrue(FullscreenNaming.isAutoName("SAFARI", appName: "Safari"))
    }

    func testIsAutoName_matchesShortAppName() {
        XCTAssertTrue(FullscreenNaming.isAutoName("Edge", appName: "Microsoft Edge Beta"))
        XCTAssertTrue(FullscreenNaming.isAutoName("edge", appName: "Microsoft Edge Beta"))
    }

    func testIsAutoName_userChosenName_isNotAuto() {
        let userName = "Zq Research 7f3c"
        XCTAssertFalse(FullscreenNaming.isAutoName(userName, appName: "Safari"))
        XCTAssertFalse(FullscreenNaming.isAutoName(userName, appName: nil))
    }

    /// Relies on Calculator.app, which ships with every macOS in /System/Applications.
    func testIsAutoName_installedAppName_isAuto() {
        XCTAssertTrue(FullscreenNaming.isAutoName("Calculator", appName: nil))
        XCTAssertTrue(FullscreenNaming.isAutoName("calculator", appName: "Safari"))
    }
}
