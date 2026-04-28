//
//  Extensions.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 24/11/20.
//

import Cocoa
import Foundation
import KeyboardShortcuts
import SwiftUI

extension NSString {
    func drawVerticallyCentered(in rect: CGRect, withAttributes attributes: [NSAttributedString.Key: Any]? = nil) {
        let size = self.size(withAttributes: attributes)
        let centeredRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.size.height - size.height) / 2.0,
            width: rect.size.width,
            height: size.height)
        self.draw(in: centeredRect, withAttributes: attributes)
    }
}

extension KeyboardShortcuts.Name {
    static let refresh = Self(
        "refresh",
        default: .init(.r, modifiers: [.control, .option, .command]))
    static let preferences = Self(
        "preferences",
        default: .init(.p, modifiers: [.control, .option, .command]))
    static let quickRename = Self(
        "quickRename",
        default: .init(.n, modifiers: [.control, .option, .command]))
}

func systemSettingsName() -> String {
    if #available(macOS 13.0, *) {
        return String(localized: "System Settings")
    } else {
        return String(localized: "System Preferences")
    }
}

/// Notification posted when the user changes a setting that requires a redraw.
let SettingsChangedName = NSNotification.Name("SettingsChanged")

/// Notification posted by the auto-refresh timer.
let AutoRefreshTriggeredName = NSNotification.Name("AutoRefreshTriggered")

/// Notify the app that a setting changed and spaces should be redrawn.
func postSettingsChanged() {
    NotificationCenter.default.post(name: SettingsChangedName, object: nil)
}

// MARK: - NSColor Extensions

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
    func contrastingTextColor(withAlpha alpha: CGFloat, over background: NSColor) -> NSColor {
        guard let fg = self.usingColorSpace(.sRGB),
              let bg = background.usingColorSpace(.sRGB) else {
            return contrastingTextColor
        }
        let a = min(max(alpha, 0), 1)
        let blended = NSColor(
            srgbRed: a * fg.redComponent + (1 - a) * bg.redComponent,
            green: a * fg.greenComponent + (1 - a) * bg.greenComponent,
            blue: a * fg.blueComponent + (1 - a) * bg.blueComponent,
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

// MARK: - ColorWellView

struct ColorWellView: NSViewRepresentable {
    @Binding var selectedColor: NSColor?
    var onColorChange: ((NSColor?) -> Void)?

    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell()
        colorWell.isBordered = true
        colorWell.isContinuous = true
        colorWell.color = selectedColor ?? NSColor.systemGray
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorDidChange(_:))
        return colorWell
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        context.coordinator.onColorChange = onColorChange

        // Don't update color if the panel is active - let user interaction control it
        if !nsView.isActive {
            let newColor = selectedColor ?? NSColor.systemGray
            if nsView.color != newColor {
                nsView.color = newColor
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onColorChange: onColorChange)
    }

    class Coordinator: NSObject {
        var onColorChange: ((NSColor?) -> Void)?

        init(onColorChange: ((NSColor?) -> Void)?) {
            self.onColorChange = onColorChange
        }

        @objc func colorDidChange(_ sender: NSColorWell) {
            onColorChange?(sender.color)
        }
    }
}
