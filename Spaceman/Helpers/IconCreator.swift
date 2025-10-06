//
//  IconCreator.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import AppKit
import Foundation
import SwiftUI

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

    public func getIcon(for spaces: [Space], buttonFrame: NSRect? = nil) -> NSImage {
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
            //icons = resizeIcons(filteredSpaces, icons, layoutMode)
            break
        case .numbers:
            icons = createNumberedIcons(filteredSpaces)
        case .numbersAndRects:
            icons = createRectWithNumbersIcons(icons, filteredSpaces)
        case .names, .numbersAndNames:
            icons = createNamedIcons(icons, filteredSpaces, withNumbers: displayStyle == .numbersAndNames)
        }

        let iconsWithDisplayProperties = getIconsWithDisplayProps(icons: icons, spaces: filteredSpaces)
        if layoutMode == .dualRows {
            return mergeIconsTwoRows(iconsWithDisplayProperties, buttonFrame: buttonFrame)
        } else {
            return mergeIcons(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID, buttonFrame: buttonFrame)
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

            image.lockFocus()
            spaceID.drawVerticallyCentered(
                in: textRect,
                withAttributes: getStringAttributes(alpha: !s.isCurrentSpace ? 0.4 : 1))
            image.unlockFocus()

            newIcons.append(image)
        }
        return newIcons
    }

    public func createRectWithNumberIcon(icons: [NSImage], index: Int, space: Space, fraction: Float = 1.0) -> NSImage {
        iconSize.width = CGFloat(sizes.ICON_WIDTH_SMALL)

        let textRect = NSRect(origin: CGPoint.zero, size: iconSize)
        let spaceID = space.spaceByDesktopID

        let iconImage = NSImage(size: iconSize)
        let numberImage = NSImage(size: iconSize)

        numberImage.lockFocus()
        spaceID.drawVerticallyCentered(
            in: textRect,
            withAttributes: getStringAttributes(alpha: 1))
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
            let textSize = spaceText.size(withAttributes: getStringAttributes(alpha: 1))
            let textWithMarginSize = NSMakeSize(textSize.width + 4, CGFloat(sizes.ICON_HEIGHT))

            // Check if the text width exceeds the icon's width
            let textImageSize = textSize.width > iconSize.width ? textWithMarginSize : iconSize
            let iconImage = NSImage(size: textImageSize)
            let textImage = NSImage(size: textImageSize)
            let textRect = NSRect(origin: CGPoint.zero, size: textImageSize)

            textImage.lockFocus()
            spaceText.drawVerticallyCentered(
                in: textRect,
                withAttributes: getStringAttributes(alpha: 1))
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
            index += 1
        }

        return newIcons
    }

    private func getIconsWithDisplayProps(icons: [NSImage], spaces: [Space]) -> [(NSImage, Bool, Bool, String, String?)] {
        var iconsWithDisplayProperties = [(NSImage, Bool, Bool, String, String?)]()
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
            iconsWithDisplayProperties.append((icons[index], nextSpaceIsOnDifferentDisplay, spaces[index].isFullScreen, spaces[index].spaceID, spaces[index].colorHex))
        }

        return iconsWithDisplayProperties
    }

    private func mergeIcons(_ iconsWithDisplayProperties: [(image: NSImage, nextSpaceOnDifferentDisplay: Bool, isFullScreen: Bool, spaceID: String, colorHex: String?)], indexMap: [String: Int], buttonFrame: NSRect? = nil) -> NSImage {
        let numIcons = iconsWithDisplayProperties.count
        let combinedIconWidth = CGFloat(iconsWithDisplayProperties.reduce(0) { (result, icon) in
            result + icon.image.size.width
        })
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
        var hasAnyColoredIcon = false
        for icon in iconsWithDisplayProperties {
            // Apply color tinting if specified
            let iconToUse: NSImage
            if let colorHex = icon.colorHex, let color = NSColor.fromHex(colorHex) {
                iconToUse = tintIcon(icon.image, with: color)
                hasAnyColoredIcon = true
            } else {
                iconToUse = icon.image
            }

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

    private func mergeIconsTwoRows(_ iconsWithDisplayProperties: [(image: NSImage, nextSpaceOnDifferentDisplay: Bool, isFullScreen: Bool, spaceID: String, colorHex: String?)], buttonFrame: NSRect? = nil) -> NSImage {
        // Column describes a stacked pair (top/bottom) and its rendered width and trailing gap
        struct Column { var top: (NSImage, Bool, Int, String, String?)?; var bottom: (NSImage, Bool, Int, String, String?)?; var width: CGFloat = 0; var gapAfter: CGFloat = 0 }

        // Pre-compute the target index for each icon: positive for numbered spaces; negative for fullscreen pseudo indices
        var assignedIndices: [Int] = []
        var numbered = 1
        var fullscreen = 1
        for i in iconsWithDisplayProperties {
            if i.isFullScreen { assignedIndices.append(-fullscreen); fullscreen += 1 }
            else { assignedIndices.append(numbered); numbered += 1 }
        }

        // Build columns depending on fill order preference
        var columns: [Column] = []
        switch dualRowFillOrder {
        case .byColumn:
            // Original behavior: fill top then bottom per column
            var current = Column()
            var placeTop = true
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                let tag = assignedIndices[idx]
                if placeTop {
                    current.top = (icon.image, icon.isFullScreen, tag, icon.spaceID, icon.colorHex)
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = false
                } else {
                    current.bottom = (icon.image, icon.isFullScreen, tag, icon.spaceID, icon.colorHex)
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
                if idx == iconsWithDisplayProperties.count - 1 && (current.top != nil || current.bottom != nil) {
                    current.gapAfter = 0
                    columns.append(current)
                }
            }
        case .byRow:
            // New behavior: fill entire top row left-to-right, then bottom row
            // First, segment by display to place display gaps correctly
            var segments: [[(image: NSImage, nextDisplay: Bool, isFull: Bool, tag: Int, spaceID: String, colorHex: String?)]] = []
            var cur: [(NSImage, Bool, Bool, Int, String, String?)] = []
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                cur.append((icon.image, icon.nextSpaceOnDifferentDisplay, icon.isFullScreen, assignedIndices[idx], icon.spaceID, icon.colorHex))
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
                        let t = top[i]
                        col.top = (t.image, t.isFull, t.tag, t.spaceID, t.colorHex)
                        col.width = max(col.width, t.image.size.width)
                    }
                    if i < bottom.count {
                        let b = bottom[i]
                        col.bottom = (b.image, b.isFull, b.tag, b.spaceID, b.colorHex)
                        col.width = max(col.width, b.image.size.width)
                    }
                    // Add inter-column gap. After the last column of a display, add display gap (except trailing overall)
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
        var hasAnyColoredIcon = false

        for col in columns {
            // Simple gap splitting: each icon owns half the gap on each side
            // (col.gapAfter already accounts for display gaps vs regular gaps)
            let iconLeft = left - (col.gapAfter / 2.0)
            let iconRight = left + col.width + (col.gapAfter / 2.0)

            if let top = col.top {
                let iconToUse: NSImage
                if let colorHex = top.4, let color = NSColor.fromHex(colorHex) {
                    iconToUse = tintIcon(top.0, with: color)
                    hasAnyColoredIcon = true
                } else {
                    iconToUse = top.0
                }
                iconToUse.draw(at: NSPoint(x: left, y: iconSize.height + gap), from: .zero, operation: .sourceOver, fraction: 1.0)
                iconWidths.append(IconWidth(left: iconLeft + dynamicLeftMargin, right: iconRight + dynamicLeftMargin, top: iconSize.height + gap, bottom: imageHeight, index: top.2))
            }
            if let bottom = col.bottom {
                let iconToUse: NSImage
                if let colorHex = bottom.4, let color = NSColor.fromHex(colorHex) {
                    iconToUse = tintIcon(bottom.0, with: color)
                    hasAnyColoredIcon = true
                } else {
                    iconToUse = bottom.0
                }
                iconToUse.draw(at: NSPoint(x: left, y: 0), from: .zero, operation: .sourceOver, fraction: 1.0)
                iconWidths.append(IconWidth(left: iconLeft + dynamicLeftMargin, right: iconRight + dynamicLeftMargin, top: 0, bottom: iconSize.height, index: bottom.2))
            }
            left += col.width + col.gapAfter
        }
        image.isTemplate = !hasAnyColoredIcon
        image.unlockFocus()
        return image
    }

    private func getStringAttributes(alpha: CGFloat, fontSize: CGFloat = .zero) -> [NSAttributedString.Key : Any] {
        let actualFontSize = fontSize == .zero ? CGFloat(sizes.FONT_SIZE) : fontSize
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        return [
            .foregroundColor: NSColor.black.withAlphaComponent(alpha),
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
}
