//
//  ColorTests.swift
//  SpacemanTests
//

import XCTest
@testable import Spaceman

final class ColorTests: XCTestCase {

    // MARK: - fromHex

    func testFromHex_sixDigits_isOpaque() throws {
        let color = try XCTUnwrap(NSColor.fromHex("FF5733"))
        XCTAssertEqual(color.toHexString(), "FF5733FF")
    }

    func testFromHex_eightDigits_keepsAlpha() throws {
        let color = try XCTUnwrap(NSColor.fromHex("00000080"))
        XCTAssertEqual(color.toHexString(), "00000080")
    }

    func testFromHex_acceptsHashPrefix() throws {
        let color = try XCTUnwrap(NSColor.fromHex("#FF5733"))
        XCTAssertEqual(color.toHexString(), "FF5733FF")
    }

    func testFromHex_trimsWhitespace() throws {
        let color = try XCTUnwrap(NSColor.fromHex("  FF5733\n"))
        XCTAssertEqual(color.toHexString(), "FF5733FF")
    }

    func testFromHex_isCaseInsensitive() throws {
        let color = try XCTUnwrap(NSColor.fromHex("ff5733"))
        XCTAssertEqual(color.toHexString(), "FF5733FF")
    }

    func testFromHex_wrongLength_isNil() {
        XCTAssertNil(NSColor.fromHex(""))
        XCTAssertNil(NSColor.fromHex("FFF"))
        XCTAssertNil(NSColor.fromHex("FF573"))
        XCTAssertNil(NSColor.fromHex("FF5733F"))
        XCTAssertNil(NSColor.fromHex("FF5733FF00"))
    }

    func testFromHex_noHexDigitsAtAll_isNil() {
        XCTAssertNil(NSColor.fromHex("GGGGGG"))
    }

    /// Scanner stops at the first non-hex character but still reports success,
    /// so without an explicit check a trailing invalid character slips through as a different color.
    func testFromHex_trailingInvalidCharacter_isNil() {
        XCTAssertNil(NSColor.fromHex("12345G"))
        XCTAssertNil(NSColor.fromHex("FF5733FZ"))
    }

    // MARK: - toHexString / round trip

    func testToHexString_blackAndWhite() {
        XCTAssertEqual(NSColor.black.toHexString(), "000000FF")
        XCTAssertEqual(NSColor.white.toHexString(), "FFFFFFFF")
    }

    /// Stored space colors go through fromHex → toHexString on every save;
    /// the value must not drift.
    func testRoundTrip_isStableForAllChannelValues() throws {
        for value in 0...255 {
            let hex = String(format: "%02X%02X%02X%02X", value, 255 - value, (value * 7) % 256, (value * 13) % 256)
            var current = hex
            for _ in 0..<3 {
                current = try XCTUnwrap(NSColor.fromHex(current)?.toHexString())
            }
            XCTAssertEqual(current, hex)
        }
    }

    // MARK: - relativeLuminance / contrastingTextColor

    func testRelativeLuminance_extremes() {
        XCTAssertEqual(NSColor.black.relativeLuminance, 0, accuracy: 0.0001)
        XCTAssertEqual(NSColor.white.relativeLuminance, 1, accuracy: 0.0001)
    }

    func testContrastingTextColor_darkBackground_isWhite() throws {
        XCTAssertEqual(NSColor.black.contrastingTextColor, .white)
        XCTAssertEqual(try XCTUnwrap(NSColor.fromHex("0000FF")).contrastingTextColor, .white)
    }

    func testContrastingTextColor_lightBackground_isBlack() throws {
        XCTAssertEqual(NSColor.white.contrastingTextColor, .black)
        XCTAssertEqual(try XCTUnwrap(NSColor.fromHex("FFFF00")).contrastingTextColor, .black)
    }

    func testContrastingTextColorWithAlpha_zeroAlpha_followsBackground() {
        XCTAssertEqual(NSColor.black.contrastingTextColor(withAlpha: 0, over: .white), .black)
        XCTAssertEqual(NSColor.white.contrastingTextColor(withAlpha: 0, over: .black), .white)
    }

    func testContrastingTextColorWithAlpha_fullAlpha_followsForeground() {
        XCTAssertEqual(NSColor.white.contrastingTextColor(withAlpha: 1, over: .black), .black)
        XCTAssertEqual(NSColor.black.contrastingTextColor(withAlpha: 1, over: .white), .white)
    }

    /// Inputs chosen so that an unclamped alpha lands on the other side of the threshold:
    /// alpha 2 of gray 0.5 over black would extrapolate to white (→ black text),
    /// alpha -1 of black over gray 0.5 would extrapolate to white as well.
    func testContrastingTextColorWithAlpha_clampsOutOfRangeAlpha() {
        let gray = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        XCTAssertEqual(gray.contrastingTextColor, .white)
        // Clamped to 1: gray alone
        XCTAssertEqual(gray.contrastingTextColor(withAlpha: 2, over: .black), .white)
        // Clamped to 0: gray background alone
        XCTAssertEqual(NSColor.black.contrastingTextColor(withAlpha: -1, over: gray), .white)
    }

    /// Foreground and background both need black text on their own, but their blend
    /// is dark enough to need white text, so the result must come from the blend.
    func testContrastingTextColorWithAlpha_midAlpha_usesBlend() {
        let green = NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        let lightMagenta = NSColor(srgbRed: 1, green: 0.25, blue: 1, alpha: 1)
        XCTAssertEqual(green.contrastingTextColor, .black)
        XCTAssertEqual(lightMagenta.contrastingTextColor, .black)
        XCTAssertEqual(green.contrastingTextColor(withAlpha: 0.4, over: lightMagenta), .white)
    }
}
