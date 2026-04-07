//
//  FontDesign.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-03-31.
//

import AppKit

enum FontDesign: Int, CaseIterable {
    case sans = 0
    case serif = 1
    case monospaced = 2
    case rounded = 3

    var systemDesign: NSFontDescriptor.SystemDesign {
        switch self {
        case .sans:        return .default
        case .serif:       return .serif
        case .monospaced:  return .monospaced
        case .rounded:     return .rounded
        }
    }

    var menuLabel: String {
        switch self {
        case .sans:        return String(localized: "Sans-Serif")
        case .serif:       return String(localized: "Serif")
        case .monospaced:  return String(localized: "Fixed Width")
        case .rounded:     return String(localized: "Rounded")
        }
    }
}
