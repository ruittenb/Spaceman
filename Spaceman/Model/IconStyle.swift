//
//  IconStyle.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-03-27.
//  Co-author: Claude Code
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

    var shape: IconShape {
        switch self {
        case .noDecoration:                                     return .noDecoration
        case .borderedRectangular, .filledRectangular:          return .rectangular
        case .borderedRounded, .filledRounded:                  return .rounded
        case .borderedPill, .filledPill:                        return .pill
        }
    }

    var fill: IconFill {
        return isFilled ? .filled : .bordered
    }

    /// Returns a new style with the given fill, preserving the shape.
    /// If the current style is `noDecoration`, defaults to rectangular.
    func withFill(_ fill: IconFill) -> IconStyle {
        let s = isNoDecoration ? IconShape.rectangular : shape
        switch (fill, s) {
        case (_, .noDecoration):        return .noDecoration
        case (.bordered, .rectangular): return .borderedRectangular
        case (.bordered, .rounded):     return .borderedRounded
        case (.bordered, .pill):        return .borderedPill
        case (.filled, .rectangular):   return .filledRectangular
        case (.filled, .rounded):       return .filledRounded
        case (.filled, .pill):          return .filledPill
        }
    }

    /// Returns a new style with the given shape, preserving the fill/border style.
    /// If the current style is `noDecoration`, defaults to bordered.
    func withShape(_ shape: IconShape) -> IconStyle {
        switch shape {
        case .noDecoration:
            return .noDecoration
        case .rectangular:
            return isFilled ? .filledRectangular : .borderedRectangular
        case .rounded:
            return isFilled ? .filledRounded : .borderedRounded
        case .pill:
            return isFilled ? .filledPill : .borderedPill
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
