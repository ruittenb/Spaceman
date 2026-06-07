//
//  Color.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-13.
//  Co-author: Claude Code
//

import Cocoa

extension NSColor {
    /// Convert NSColor to hex string with alpha (e.g., "FF5733FF")
    func toHexString() -> String? {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else { return nil }
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        let alpha = Int(rgbColor.alphaComponent * 255)
        return String(format: "%02X%02X%02X%02X", red, green, blue, alpha)
    }

    /// Calculate relative luminance (WCAG formula with sRGB gamma correction).
    var relativeLuminance: CGFloat {
        guard let rgb = self.usingColorSpace(.sRGB) else { return 0.5 }
        var r = rgb.redComponent
        var g = rgb.greenComponent
        var b = rgb.blueComponent
        r = (r <= 0.03928) ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        g = (g <= 0.03928) ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        b = (b <= 0.03928) ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Return black or white, whichever has better contrast against this color.
    var contrastingTextColor: NSColor {
        relativeLuminance > 0.3 ? .black : .white
    }

    /// Return black or white for contrast, accounting for alpha blending over a background.
    func contrastingTextColor(withAlpha rawAlpha: CGFloat, over background: NSColor) -> NSColor {
        guard let fgColor = self.usingColorSpace(.sRGB),
              let bgColor = background.usingColorSpace(.sRGB) else {
            return contrastingTextColor
        }
        let alpha = min(max(rawAlpha, 0), 1)
        let blended = NSColor(
            srgbRed: alpha * fgColor.redComponent + (1 - alpha) * bgColor.redComponent,
            green: alpha * fgColor.greenComponent + (1 - alpha) * bgColor.greenComponent,
            blue: alpha * fgColor.blueComponent + (1 - alpha) * bgColor.blueComponent,
            alpha: 1.0)
        return blended.relativeLuminance > 0.3 ? .black : .white
    }

    /// Create NSColor from hex string (e.g., "FF5733", "FF5733FF", or "#FF5733")
    static func fromHex(_ hexString: String) -> NSColor? {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard hex.count == 6 || hex.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }

        let red, green, blue, alpha: CGFloat
        if hex.count == 8 {
            red   = CGFloat((value & 0xFF000000) >> 24) / 255.0
            green = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            blue  = CGFloat((value & 0x0000FF00) >> 8)  / 255.0
            alpha = CGFloat( value & 0x000000FF)         / 255.0
        } else {
            red   = CGFloat((value & 0xFF0000) >> 16) / 255.0
            green = CGFloat((value & 0x00FF00) >> 8)  / 255.0
            blue  = CGFloat( value & 0x0000FF)         / 255.0
            alpha = 1.0
        }

        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
