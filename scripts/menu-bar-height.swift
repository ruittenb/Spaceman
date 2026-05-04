#!/usr/bin/env swift
import AppKit

let thickness = NSStatusBar.system.thickness
let scale = NSScreen.main?.backingScaleFactor ?? 0
let frame = NSScreen.main?.frame ?? .zero
let visible = NSScreen.main?.visibleFrame ?? .zero
let menuBarHeight = frame.maxY - visible.maxY

print("Menu bar thickness (API): \(thickness) points")
print("Menu bar height (computed): \(menuBarHeight) points")
print("Backing scale factor: \(scale)x")
print("Screen frame: \(Int(frame.width))×\(Int(frame.height)) points")
print("Visible frame: \(Int(visible.width))×\(Int(visible.height)) points")
print("macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)")

if let font = NSFont.systemFont(ofSize: 9).fontDescriptor
    .withDesign(.monospaced)
    .flatMap({ NSFont(descriptor: $0, size: 9) }) {
    print("9pt monospaced line height: \(font.ascender - font.descender + font.leading)")
}

let appearance = NSApp?.effectiveAppearance.bestMatch(
    from: [.darkAqua, .aqua]) ?? .aqua
print("Appearance: \(appearance.rawValue)")
