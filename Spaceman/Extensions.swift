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
    static let refresh = Self("refresh")
    static let preferences = Self("preferences")
}

func systemSettingsName() -> String {
    if #available(macOS 13.0, *) {
        return String(localized: "System Settings")
    } else {
        return String(localized: "System Preferences")
    }
}

/// Notification name used to trigger a full space redraw.
let ButtonPressedName = NSNotification.Name("ButtonPressed")

/// Notify the app that a setting changed and spaces should be redrawn.
func postRefreshNotification() {
    NotificationCenter.default.post(name: ButtonPressedName, object: nil)
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
