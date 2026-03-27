//
//  IconStyle.swift
//  Spaceman
//
//  Created by Claude Code on 27/03/2026.
//

import AppKit

enum IconStyle: Int, CaseIterable {
    case bareText = 0
    case rectangularBordered = 1
    case rectangularFilled = 2
    case roundedBordered = 3
    case roundedFilled = 4
    case pillBordered = 5
    case pillFilled = 6

    var isBareText: Bool { self == .bareText }

    var isFilled: Bool {
        switch self {
        case .rectangularFilled, .roundedFilled, .pillFilled: return true
        default: return false
        }
    }

    var isBordered: Bool {
        switch self {
        case .rectangularBordered, .roundedBordered, .pillBordered: return true
        default: return false
        }
    }

    /// Corner radius for the decoration shape, given the bounding rect.
    func cornerRadius(for rect: NSRect) -> CGFloat {
        switch self {
        case .bareText:
            return 0
        case .rectangularBordered, .rectangularFilled:
            return 0
        case .roundedBordered, .roundedFilled:
            return 3.0
        case .pillBordered, .pillFilled:
            return rect.height / 2
        }
    }

    /// Fullscreen variant: rectangular becomes pill (and vice versa),
    /// preserving the fill style. Bare text stays bare text.
    var fullscreenVariant: IconStyle {
        switch self {
        case .bareText:            return .bareText
        case .rectangularBordered: return .pillBordered
        case .rectangularFilled:   return .pillFilled
        case .roundedBordered:     return .rectangularBordered
        case .roundedFilled:       return .rectangularFilled
        case .pillBordered:        return .rectangularBordered
        case .pillFilled:          return .rectangularFilled
        }
    }

    var menuLabel: String {
        switch self {
        case .bareText:            return String(localized: "Bare text")
        case .rectangularBordered: return String(localized: "Rectangular, bordered")
        case .rectangularFilled:   return String(localized: "Rectangular, filled")
        case .roundedBordered:     return String(localized: "Rounded, bordered")
        case .roundedFilled:       return String(localized: "Rounded, filled")
        case .pillBordered:        return String(localized: "Pill, bordered")
        case .pillFilled:          return String(localized: "Pill, filled")
        }
    }
}
