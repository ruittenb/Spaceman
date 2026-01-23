//
//  IconCreator.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import AppKit
import Foundation
import SwiftUI

/// Holds the data needed to render and position a space icon in the merged image.
private struct IconRenderInfo {
    let image: NSImage
    let nextSpaceOnDifferentDisplay: Bool
    let isFullScreen: Bool
    let spaceID: String
    let colorHex: String?
}

class IconCreator {
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.medium
    @AppStorage("displayStyle") private var displayStyle = DisplayStyle.numbersAndRects
    @AppStorage("dualRowFillOrder") private var dualRowFillOrder = DualRowFillOrder.byColumn
    // Legacy flag kept for backward compatibility; use visibleSpacesMode instead
    @AppStorage("hideInactiveSpaces") private var hideInactiveSpaces = false
    @AppStorage("visibleSpacesMode") private var visibleSpacesModeRaw: Int = VisibleSpacesMode.all.rawValue
    @AppStorage("neighborRadius") private var neighborRadius = 1

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }
    private var displayCount = 1
    private var iconSize = NSSize(width: 0, height: 0)
    private var gapWidth = CGFloat.zero
    private var displayGapWidth = CGFloat.zero
    private let spaceFilter = SpaceFilter()

    public var sizes: GuiSize!
    public var iconWidths: [IconWidth] = []

    public func getIcon(for spaces: [Space], buttonFrame: NSRect? = nil, appearance: NSAppearance? = nil) -> NSImage {
        sizes = Constants.sizes[layoutMode]
        gapWidth = CGFloat(sizes.GAP_WIDTH_SPACES)
        displayGapWidth = CGFloat(sizes.GAP_WIDTH_DISPLAYS)
        iconSize = NSSize(
            width: sizes.ICON_WIDTH_SMALL,
            height: sizes.ICON_HEIGHT)

        var icons = [NSImage]()

        // Precompute switch indices for all spaces (use actual macOS global space numbers)
        var switchIndexBySpaceID: [String: Int] = [:]
        var fullIndex = 1
        for s in spaces {
            if s.isFullScreen {
                // Map first two fullscreen spaces to -1 and -2
                if fullIndex <= 2 {
                    switchIndexBySpaceID[s.spaceID] = -fullIndex
                }
                fullIndex += 1
            } else {
                // Use actual macOS global space number, not sequential numbering
                if s.spaceNumber <= 10 {
                    switchIndexBySpaceID[s.spaceID] = s.spaceNumber
                }
            }
        }

        // Determine which spaces to include based on mode
        let filteredSpaces = filterSpaces(spaces)

        // Gracefully handle transient empty state (e.g., during Mission Control updates)
        if filteredSpaces.isEmpty {
            iconWidths = []
            let empty = NSImage(size: NSSize(width: 1, height: iconSize.height))
            empty.isTemplate = true
            return empty
        }

        for s in filteredSpaces {
            let iconResourceName: String
            switch (s.isCurrentSpace, s.isFullScreen, displayStyle) {
            case (true, true, .names):
                iconResourceName = "SpaceIconNamedFullActive"
            case (false, true, .names):
                iconResourceName = "SpaceIconNamedFullInactive"
            case (true, true, .rects):
                iconResourceName = "SpaceIconNumFullActive"
            case (false, true, .rects):
                iconResourceName = "SpaceIconNumFullInactive"
            case (true, true, .numbersAndNames),
                 (true, true, .numbersAndRects):
                // avoid 「 」 marks overlapping with text
                iconResourceName = "SpaceIconNumNormalActive"
            case (false, true, .numbersAndNames),
                 (false, true, .numbersAndRects):
                // avoid 「 」 marks overlapping with text
                iconResourceName = "SpaceIconNumNormalInactive"
            case (true, false, _):
                iconResourceName = "SpaceIconNumNormalActive"
            default:
                iconResourceName = "SpaceIconNumNormalInactive"
            }

            icons.append(NSImage(imageLiteralResourceName: iconResourceName))
        }

        switch displayStyle {
        case .rects:
            icons = createColoredRects(icons, filteredSpaces)
        case .numbers:
            icons = createNumberedIcons(filteredSpaces)
        case .numbersAndRects:
            icons = createRectWithNumbersIcons(icons, filteredSpaces)
        case .names, .numbersAndNames:
            icons = createNamedIcons(icons, filteredSpaces, withNumbers: displayStyle == .numbersAndNames)
        }

        let iconsWithDisplayProperties = getIconsWithDisplayProps(icons: icons, spaces: filteredSpaces)
        if layoutMode == .dualRows {
            return mergeIconsTwoRows(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID, buttonFrame: buttonFrame, appearance: appearance)
        } else {
            return mergeIcons(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID, buttonFrame: buttonFrame, appearance: appearance)
        }
    }

    private func filterSpaces(_ spaces: [Space]) -> [Space] {
        // Backwards compatibility: if legacy flag is true and visible mode wasn't set explicitly, treat as current only
        let mode: VisibleSpacesMode = {
            if UserDefaults.standard.object(forKey: "visibleSpacesMode") == nil && hideInactiveSpaces {
                return .currentOnly
            }
            return visibleSpacesMode
        }()

        return spaceFilter.filter(spaces, mode: mode, neighborRadius: neighborRadius)
    }

    private func createNumberedIcons(_ spaces: [Space]) -> [NSImage] {
        var newIcons = [NSImage]()

        for s in spaces {
            let textRect = NSRect(origin: CGPoint.zero, size: iconSize)
            let spaceID = s.spaceByDesktopID

            let image = NSImage(size: iconSize)

            // For numbers-only mode with custom color, use the color for the text itself
            // (there's no background to contrast against)
            if let colorHex = s.colorHex, let textColor = NSColor.fromHex(colorHex) {
                image.lockFocus()
                spaceID.drawVerticallyCentered(
                    in: textRect,
                    withAttributes: getStringAttributes(alpha: !s.isCurrentSpace ? 0.4 : 1, color: textColor))
                image.isTemplate = false
                image.unlockFocus()
            } else {
                image.lockFocus()
                spaceID.drawVerticallyCentered(
                    in: textRect,
                    withAttributes: getStringAttributes(alpha: !s.isCurrentSpace ? 0.4 : 1, color: .black))
                image.isTemplate = true
                image.unlockFocus()
            }

            newIcons.append(image)
        }
        return newIcons
    }

    public func createRectWithNumberIcon(icons: [NSImage], index: Int, space: Space, fraction: Float = 1.0) -> NSImage {
        iconSize.width = CGFloat(sizes.ICON_WIDTH_SMALL)

        let textRect = NSRect(origin: CGPoint.zero, size: iconSize)
        let spaceID = space.spaceByDesktopID

        let iconImage = NSImage(size: iconSize)

        // If space has a custom color, tint background first then draw text on top
        if let colorHex = space.colorHex, let bgColor = NSColor.fromHex(colorHex) {
            let textColor = getContrastingTextColor(for: bgColor)

            iconImage.lockFocus()
            // Draw and tint the background shape
            icons[index].draw(
                in: textRect,
                from: NSRect.zero,
                operation: NSCompositingOperation.sourceOver,
                fraction: CGFloat(fraction))
            bgColor.setFill()
            NSRect(origin: .zero, size: iconSize).fill(using: .sourceAtop)

            // Draw text on top in contrasting color
            spaceID.drawVerticallyCentered(
                in: textRect,
                withAttributes: getStringAttributes(alpha: 1, color: textColor))
            iconImage.isTemplate = false
            iconImage.unlockFocus()
        } else {
            // For non-colored icons, use the knockout technique
            let numberImage = NSImage(size: iconSize)

            numberImage.lockFocus()
            spaceID.drawVerticallyCentered(
                in: textRect,
                withAttributes: getStringAttributes(alpha: 1, color: .black))
            numberImage.unlockFocus()

            iconImage.lockFocus()
            icons[index].draw(
                in: textRect,
                from: NSRect.zero,
                operation: NSCompositingOperation.sourceOver,
                fraction: CGFloat(fraction))
            numberImage.draw(
                in: textRect,
                from: NSRect.zero,
                operation: NSCompositingOperation.destinationOut,
                fraction: 1.0)
            iconImage.isTemplate = true
            iconImage.unlockFocus()
        }

        return iconImage
    }

    private func createRectWithNumbersIcons(_ icons: [NSImage], _ spaces: [Space]) -> [NSImage] {
        var index = 0
        var newIcons = [NSImage]()
        for s in spaces {
            let iconImage = createRectWithNumberIcon(icons: icons, index: index, space: s)
            newIcons.append(iconImage)
            index += 1
        }
        return newIcons
    }

    private func createColoredRects(_ icons: [NSImage], _ spaces: [Space]) -> [NSImage] {
        var index = 0
        var newIcons = [NSImage]()

        for s in spaces {
            let iconImage = NSImage(size: icons[index].size)

            // If space has a custom color, tint the rectangle
            if let colorHex = s.colorHex, let bgColor = NSColor.fromHex(colorHex) {
                iconImage.lockFocus()
                // Draw and tint the rectangle
                icons[index].draw(
                    at: .zero,
                    from: NSRect(origin: .zero, size: icons[index].size),
                    operation: .sourceOver,
                    fraction: 1.0)
                bgColor.setFill()
                NSRect(origin: .zero, size: icons[index].size).fill(using: .sourceAtop)
                iconImage.isTemplate = false
                iconImage.unlockFocus()
            } else {
                // For non-colored icons, just use the template
                iconImage.lockFocus()
                icons[index].draw(
                    at: .zero,
                    from: NSRect(origin: .zero, size: icons[index].size),
                    operation: .sourceOver,
                    fraction: 1.0)
                iconImage.isTemplate = true
                iconImage.unlockFocus()
            }

            newIcons.append(iconImage)
            index += 1
        }
        return newIcons
    }

    private func createNamedIcons(_ icons: [NSImage], _ spaces: [Space], withNumbers: Bool) -> [NSImage] {
        var index = 0
        var newIcons = [NSImage]()

        iconSize.width = CGFloat(withNumbers ? sizes.ICON_WIDTH_XLARGE : sizes.ICON_WIDTH_LARGE)

        for s in spaces {
            let spaceID = s.spaceByDesktopID
            let spaceNumberPrefix = withNumbers ? "\(spaceID):" : ""
            let ucName = s.spaceName.uppercased()
            // Truncate name for space-constrained modes
            let shownName: String
            switch visibleSpacesMode {
            case .all:
                shownName = String(ucName.prefix(4))
            case .neighbors:
                shownName = String(ucName.prefix(6))
            case .currentOnly:
                shownName = ucName
            }
            let spaceText = NSString(string: "\(spaceNumberPrefix)\(shownName)")

            // If space has a custom color, tint background first then draw text on top
            if let colorHex = s.colorHex, let bgColor = NSColor.fromHex(colorHex) {
                let textColor = getContrastingTextColor(for: bgColor)
                let textSize = spaceText.size(withAttributes: getStringAttributes(alpha: 1, color: textColor))
                let textWithMarginSize = NSMakeSize(textSize.width + 4, CGFloat(sizes.ICON_HEIGHT))

                // Check if the text width exceeds the icon's width
                let textImageSize = textSize.width > iconSize.width ? textWithMarginSize : iconSize
                let iconImage = NSImage(size: textImageSize)
                let textRect = NSRect(origin: CGPoint.zero, size: textImageSize)

                iconImage.lockFocus()
                // Draw and tint the background shape
                icons[index].draw(
                    in: textRect,
                    from: NSRect.zero,
                    operation: NSCompositingOperation.sourceOver,
                    fraction: 1.0)
                bgColor.setFill()
                NSRect(origin: .zero, size: textImageSize).fill(using: .sourceAtop)

                // Draw text on top in contrasting color
                spaceText.drawVerticallyCentered(
                    in: textRect,
                    withAttributes: getStringAttributes(alpha: 1, color: textColor))
                iconImage.isTemplate = false
                iconImage.unlockFocus()

                newIcons.append(iconImage)
            } else {
                // For non-colored icons, use the knockout technique
                let textSize = spaceText.size(withAttributes: getStringAttributes(alpha: 1, color: .black))
                let textWithMarginSize = NSMakeSize(textSize.width + 4, CGFloat(sizes.ICON_HEIGHT))

                // Check if the text width exceeds the icon's width
                let textImageSize = textSize.width > iconSize.width ? textWithMarginSize : iconSize
                let iconImage = NSImage(size: textImageSize)
                let textImage = NSImage(size: textImageSize)
                let textRect = NSRect(origin: CGPoint.zero, size: textImageSize)

                textImage.lockFocus()
                spaceText.drawVerticallyCentered(
                    in: textRect,
                    withAttributes: getStringAttributes(alpha: 1, color: .black))
                textImage.unlockFocus()

                iconImage.lockFocus()
                icons[index].draw(
                    in: textRect,
                    from: NSRect.zero,
                    operation: NSCompositingOperation.sourceOver,
                    fraction: 1.0)
                textImage.draw(
                    in: textRect,
                    from: NSRect.zero,
                    operation: NSCompositingOperation.destinationOut,
                    fraction: 1.0)
                iconImage.isTemplate = true
                iconImage.unlockFocus()

                newIcons.append(iconImage)
            }

            index += 1
        }

        return newIcons
    }

    private func getIconsWithDisplayProps(icons: [NSImage], spaces: [Space]) -> [IconRenderInfo] {
        var iconsWithDisplayProperties = [IconRenderInfo]()
        guard spaces.count > 0 else { return iconsWithDisplayProperties }
        var currentDisplayID = spaces[0].displayID
        displayCount = 1

        for index in 0 ..< spaces.count {
            var nextSpaceIsOnDifferentDisplay = false
            if index + 1 < spaces.count {
                let nextDisplayID = spaces[index + 1].displayID
                if nextDisplayID != currentDisplayID {
                    currentDisplayID = nextDisplayID
                    displayCount += 1
                    nextSpaceIsOnDifferentDisplay = true
                }
            }
            iconsWithDisplayProperties.append(IconRenderInfo(
                image: icons[index],
                nextSpaceOnDifferentDisplay: nextSpaceIsOnDifferentDisplay,
                isFullScreen: spaces[index].isFullScreen,
                spaceID: spaces[index].spaceID,
                colorHex: spaces[index].colorHex
            ))
        }

        return iconsWithDisplayProperties
    }

    private func mergeIcons(_ icons: [IconRenderInfo], indexMap: [String: Int], buttonFrame: NSRect? = nil, appearance: NSAppearance? = nil) -> NSImage {
        let numIcons = icons.count
        let combinedIconWidth = CGFloat(icons.reduce(0) { $0 + $1.image.size.width })
        let accomodatingGapWidth = CGFloat(max(0, numIcons - 1)) * gapWidth
        let accomodatingDisplayGapWidth = CGFloat(max(0, displayCount - 1)) * displayGapWidth
        let totalIconWidth = combinedIconWidth + accomodatingGapWidth + accomodatingDisplayGapWidth
        let dynamicLeftMargin = calculateLeftMargin(buttonFrame: buttonFrame, totalIconWidth: totalIconWidth)
        let totalWidth = max(1, totalIconWidth)
        let image = NSImage(size: NSSize(width: totalWidth, height: iconSize.height))

        image.lockFocus()
        var left = CGFloat.zero
        var right: CGFloat
        iconWidths = []

        // Check if any icons have custom colors - if so, we need to apply default color to non-colored icons
        let hasAnyColoredIcon = icons.contains { $0.colorHex != nil }
        let defaultColor = hasAnyColoredIcon ? getDefaultColorForAppearance(appearance) : nil

        for icon in icons {
            let iconToUse = resolveIconForRendering(icon: icon.image, colorHex: icon.colorHex, defaultColor: defaultColor)

            iconToUse.draw(
                at: NSPoint(x: left, y: 0),
                from: NSRect.zero,
                operation: NSCompositingOperation.sourceOver,
                fraction: 1.0)

            // Simple gap splitting: each icon owns half the gap on each side
            let gap = icon.nextSpaceOnDifferentDisplay ? displayGapWidth : gapWidth
            let iconLeft = left - (gap / 2.0)
            let iconRight = left + icon.image.size.width + (gap / 2.0)

            // Calculate total width including full gap for positioning next icon
            right = left + icon.image.size.width + gap

            // Use precomputed index mapping to preserve correct switching
            let targetIndex = indexMap[icon.spaceID] ?? -99 // invalid => onError
            iconWidths.append(IconWidth(left: iconLeft + dynamicLeftMargin, right: iconRight + dynamicLeftMargin, index: targetIndex))
            left = right
        }

        // Only use template mode if no icons have custom colors
        image.isTemplate = !hasAnyColoredIcon
        image.unlockFocus()

        return image
    }

    private func mergeIconsTwoRows(_ icons: [IconRenderInfo], indexMap: [String: Int], buttonFrame: NSRect? = nil, appearance: NSAppearance? = nil) -> NSImage {
        // Column describes a stacked pair (top/bottom) and its rendered width and trailing gap
        struct Column {
            var top: IconRenderInfo?
            var bottom: IconRenderInfo?
            var width: CGFloat = 0
            var gapAfter: CGFloat = 0
        }

        // Build columns depending on fill order preference
        var columns: [Column] = []
        switch dualRowFillOrder {
        case .byColumn:
            // Fill top then bottom per column
            var current = Column()
            var placeTop = true
            for icon in icons {
                if placeTop {
                    current.top = icon
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = false
                } else {
                    current.bottom = icon
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = true
                }
                let isColumnEnd = placeTop || icon.nextSpaceOnDifferentDisplay
                if isColumnEnd {
                    current.gapAfter = icon.nextSpaceOnDifferentDisplay ? displayGapWidth : gapWidth
                    columns.append(current)
                    current = Column()
                    placeTop = true
                }
            }
            // Append any remaining partial column
            if current.top != nil || current.bottom != nil {
                current.gapAfter = 0
                columns.append(current)
            }

        case .byRow:
            // Fill entire top row left-to-right, then bottom row
            // First, segment by display to place display gaps correctly
            var segments: [[IconRenderInfo]] = []
            var cur: [IconRenderInfo] = []
            for icon in icons {
                cur.append(icon)
                if icon.nextSpaceOnDifferentDisplay { segments.append(cur); cur = [] }
            }
            if !cur.isEmpty { segments.append(cur) }

            for (segIdx, seg) in segments.enumerated() {
                let n = seg.count
                let topCount = Int(ceil(Double(n) / 2.0))
                let top = Array(seg.prefix(topCount))
                let bottom = Array(seg.dropFirst(topCount))
                let maxLen = max(top.count, bottom.count)
                for i in 0..<maxLen {
                    var col = Column()
                    if i < top.count {
                        col.top = top[i]
                        col.width = max(col.width, top[i].image.size.width)
                    }
                    if i < bottom.count {
                        col.bottom = bottom[i]
                        col.width = max(col.width, bottom[i].image.size.width)
                    }
                    // After the last column of a display, add display gap (except trailing overall)
                    let isLastInSegment = (i == maxLen - 1)
                    col.gapAfter = isLastInSegment ? displayGapWidth : gapWidth
                    columns.append(col)
                }
                // Avoid display gap after final segment
                if segIdx == segments.count - 1, var last = columns.popLast() {
                    last.gapAfter = 0
                    columns.append(last)
                }
            }
        }

        // Render
        let totalWidth = columns.reduce(CGFloat(0)) { $0 + $1.width + $1.gapAfter }
        let dynamicLeftMargin = calculateLeftMargin(buttonFrame: buttonFrame, totalIconWidth: totalWidth)
        let gap = CGFloat(sizes.GAP_HEIGHT_DUALROWS)
        let imageHeight = iconSize.height * 2 + gap
        let image = NSImage(size: NSSize(width: totalWidth, height: imageHeight))

        image.lockFocus()
        var left = CGFloat.zero
        iconWidths = []

        // Check if any icons have custom colors - if so, we need to apply default color to non-colored icons
        let hasAnyColoredIcon = columns.contains { col in
            col.top?.colorHex != nil || col.bottom?.colorHex != nil
        }
        let defaultColor = hasAnyColoredIcon ? getDefaultColorForAppearance(appearance) : nil

        for col in columns {
            // Simple gap splitting: each icon owns half the gap on each side
            let iconLeft = left - (col.gapAfter / 2.0)
            let iconRight = left + col.width + (col.gapAfter / 2.0)

            if let top = col.top {
                let iconToUse = resolveIconForRendering(icon: top.image, colorHex: top.colorHex, defaultColor: defaultColor)
                iconToUse.draw(at: NSPoint(x: left, y: iconSize.height + gap), from: .zero, operation: .sourceOver, fraction: 1.0)
                let targetIndex = indexMap[top.spaceID] ?? -99
                iconWidths.append(IconWidth(left: iconLeft + dynamicLeftMargin, right: iconRight + dynamicLeftMargin, top: iconSize.height + gap, bottom: imageHeight, index: targetIndex))
            }
            if let bottom = col.bottom {
                let iconToUse = resolveIconForRendering(icon: bottom.image, colorHex: bottom.colorHex, defaultColor: defaultColor)
                iconToUse.draw(at: NSPoint(x: left, y: 0), from: .zero, operation: .sourceOver, fraction: 1.0)
                let targetIndex = indexMap[bottom.spaceID] ?? -99
                iconWidths.append(IconWidth(left: iconLeft + dynamicLeftMargin, right: iconRight + dynamicLeftMargin, top: 0, bottom: iconSize.height, index: targetIndex))
            }
            left += col.width + col.gapAfter
        }

        image.isTemplate = !hasAnyColoredIcon
        image.unlockFocus()
        return image
    }

    private func getStringAttributes(alpha: CGFloat, fontSize: CGFloat = .zero, color: NSColor = .black) -> [NSAttributedString.Key : Any] {
        let actualFontSize = fontSize == .zero ? CGFloat(sizes.FONT_SIZE) : fontSize
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        return [
            .foregroundColor: color.withAlphaComponent(alpha),
            .font: NSFont.monospacedSystemFont(ofSize: actualFontSize, weight: .bold),
            .paragraphStyle: paragraphStyle]
    }

    private func calculateLeftMargin(buttonFrame: NSRect?, totalIconWidth: CGFloat) -> CGFloat {
        guard let frame = buttonFrame, totalIconWidth > 0 else {
            // Fallback to known good value if frame unavailable
            return CGFloat(7)
        }

        // Calculate margin based on centering the icons within the button frame
        let availableWidth = frame.width
        let margin = (availableWidth - totalIconWidth) / 2.0
        return max(margin, 0) // Ensure non-negative margin
    }

    private func tintIcon(_ icon: NSImage, with color: NSColor) -> NSImage {
        let tinted = NSImage(size: icon.size)
        tinted.lockFocus()

        // Draw the icon first
        icon.draw(at: .zero, from: NSRect(origin: .zero, size: icon.size), operation: .sourceOver, fraction: 1.0)

        // Apply color overlay using sourceAtop to only tint the non-transparent pixels
        color.setFill()
        NSRect(origin: .zero, size: icon.size).fill(using: .sourceAtop)

        tinted.unlockFocus()
        return tinted
    }

    /// Resolves which icon image to use for rendering, applying default color if needed.
    private func resolveIconForRendering(icon: NSImage, colorHex: String?, defaultColor: NSColor?) -> NSImage {
        if colorHex != nil {
            return icon  // Already colored in the create phase
        } else if let defaultColor = defaultColor {
            return tintIcon(icon, with: defaultColor)
        }
        return icon
    }

    private func getDefaultColorForAppearance(_ appearance: NSAppearance? = nil) -> NSColor {
        // Use the provided appearance, or fall back to NSApp's appearance
        let effectiveAppearance = appearance ?? NSApp.effectiveAppearance
        let appearanceName = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])

        if appearanceName == .darkAqua {
            // Dark mode: use white/light gray for contrast
            return NSColor.white
        } else {
            // Light mode: use black/dark gray for contrast
            return NSColor.black
        }
    }

    private func calculateLuminance(_ color: NSColor) -> CGFloat {
        // Convert to RGB color space if needed
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return 0.5 // Default to medium luminance if conversion fails
        }

        // Get RGB components
        var r = rgbColor.redComponent
        var g = rgbColor.greenComponent
        var b = rgbColor.blueComponent

        // Apply gamma correction (sRGB)
        r = (r <= 0.03928) ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        g = (g <= 0.03928) ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        b = (b <= 0.03928) ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)

        // Calculate relative luminance
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func getContrastingTextColor(for backgroundColor: NSColor) -> NSColor {
        let luminance = calculateLuminance(backgroundColor)
        // WCAG threshold is typically 0.5, but 0.4 works better for colored buttons
        return luminance > 0.4 ? NSColor.black : NSColor.white
    }
}
