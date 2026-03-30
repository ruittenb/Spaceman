//
//  IconStyle.swift
//  Spaceman
//
//  Created by Claude Code on 27/03/2026.
//

import AppKit

enum IconStyle: Int, CaseIterable {
    case noDecoration = 0
    case borderedRectangular = 1
    case borderedRounded = 2
    case borderedPill = 3
    case filledRectangular = 4
    case filledRounded = 5
    case filledPill = 6

    var isNoDecoration: Bool { self == .noDecoration }

    var isFilled: Bool {
        switch self {
        case .filledRectangular, .filledRounded, .filledPill: return true
        default: return false
        }
    }

    var isBordered: Bool {
        switch self {
        case .borderedRectangular, .borderedRounded, .borderedPill: return true
        default: return false
        }
    }

    /// Corner radius for the decoration shape, given the bounding rect.
    func cornerRadius(for rect: NSRect) -> CGFloat {
        switch self {
        case .noDecoration:
            return 0
        case .borderedRectangular, .filledRectangular:
            return 0
        case .borderedRounded, .filledRounded:
            return rect.height * 0.2
        case .borderedPill, .filledPill:
            return rect.height / 2
        }
    }

    /// Fullscreen variant: rectangular becomes pill (and vice versa),
    /// preserving the fill style. No decoration stays no decoration.
    var fullscreenVariant: IconStyle {
        switch self {
        case .noDecoration:         return .noDecoration
        case .borderedRectangular:  return .borderedPill
        case .borderedRounded:      return .borderedRectangular
        case .borderedPill:         return .borderedRectangular
        case .filledRectangular:    return .filledPill
        case .filledRounded:        return .filledRectangular
        case .filledPill:           return .filledRectangular
        }
    }

    var menuLabel: String {
        switch self {
        case .noDecoration:         return String(localized: "No decoration")
        case .borderedRectangular:  return String(localized: "Bordered, rectangular")
        case .borderedRounded:      return String(localized: "Bordered, rounded")
        case .borderedPill:         return String(localized: "Bordered, pill")
        case .filledRectangular:    return String(localized: "Filled, rectangular")
        case .filledRounded:        return String(localized: "Filled, rounded")
        case .filledPill:           return String(localized: "Filled, pill")
        }
    }
}
