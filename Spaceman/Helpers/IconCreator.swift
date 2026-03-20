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
    @AppStorage("inactiveStyle") private var inactiveStyle = InactiveStyle.semiTransparent
    @AppStorage("useMinIconWidth") private var useMinIconWidth = true

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }
    private var displayCount = 1
    private var iconSize = NSSize(width: 0, height: 0)
    private var gapWidth = CGFloat.zero
    private var displayGapWidth = CGFloat.zero
    private var minIconCharWidth = 0
    private let spaceFilter = SpaceFilter()

    public var sizes: GuiSize!
    public var iconWidths: [IconWidth] = []

    public func getIcon(for spaces: [Space], appearance: NSAppearance? = nil) -> NSImage {
        sizes = Constants.sizes[layoutMode]
        gapWidth = CGFloat(sizes.GAP_WIDTH_SPACES)
        displayGapWidth = CGFloat(sizes.GAP_WIDTH_DISPLAYS)
        iconSize = NSSize(
            width: CGFloat(sizes.ICON_WIDTH_SMALL),
            height: CGFloat(sizes.ICON_HEIGHT) + Constants.boxVerticalPadding * 2)

        let switchIndexBySpaceID = Space.buildSwitchIndexMap(for: spaces)

        // Determine which spaces to include based on mode
        let filteredSpaces = filterSpaces(spaces)

        // Gracefully handle transient empty state (e.g., during Mission Control updates)
        if filteredSpaces.isEmpty {
            iconWidths = []
            let empty = NSImage(size: NSSize(width: 1, height: iconSize.height))
            empty.isTemplate = true
            return empty
        }

        // For uniform icon widths: match the longest name, capped at 4 characters
        let showsNames = displayStyle == .names || displayStyle == .numbersAndNames
        if useMinIconWidth && showsNames {
            let longestName = filteredSpaces.map { $0.spaceName.count }.max() ?? 0
            minIconCharWidth = min(longestName, 4)
        } else {
            minIconCharWidth = 0
        }

        // Pre-scan for mixed color context: when some spaces have custom colors,
        // non-colored spaces get a default color instead of template mode
        let hasAnyColoredSpace = filteredSpaces.contains { $0.colorHex != nil }
        let defaultColor: NSColor? = hasAnyColoredSpace ? getDefaultColorForAppearance(appearance) : nil

        // Create icons using unified box rendering
        let icons = filteredSpaces.map { space in
            createSpaceIcon(space: space, defaultColor: defaultColor)
        }

        let iconsWithDisplayProperties = getIconsWithDisplayProps(icons: icons, spaces: filteredSpaces)
        if layoutMode == .dualRows {
            return mergeIconsTwoRows(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID)
        } else {
            return mergeIcons(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID)
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

    // MARK: - Unified box rendering

    private func createSpaceIcon(space: Space, defaultColor: NSColor?) -> NSImage {
        // 1. Determine text content based on display style
        let text: NSString
        switch displayStyle {
        case .rects:
            text = ""
        case .numbers, .numbersAndRects:
            text = NSString(string: space.spaceByDesktopID)
        case .names:
            text = NSString(string: String(space.spaceName.prefix(Constants.maxSpaceNameLength)))
        case .numbersAndNames:
            let name = String(space.spaceName.prefix(Constants.maxSpaceNameLength))
            text = NSString(string: "\(space.spaceByDesktopID):\(name)")
        }

        // 2. Determine box color and template mode
        let boxColor: NSColor
        let useTemplate: Bool
        if let colorHex = space.colorHex, let customColor = NSColor.fromHex(colorHex) {
            boxColor = customColor
            useTemplate = false
        } else if let defaultColor = defaultColor {
            boxColor = defaultColor
            useTemplate = false
        } else {
            boxColor = .black
            useTemplate = true
        }

        // 3. Calculate icon size (dynamic width based on text)
        let isBareNumbers = displayStyle == .numbers
        let measureAttrs = getStringAttributes(alpha: 1, color: .black)
        let monoCharWidth = ("0" as NSString).size(withAttributes: measureAttrs).width
        let padding = Constants.boxPadding * 2
        let baseMinWidth = CGFloat(sizes.ICON_WIDTH_SMALL)

        // Content width: measured text, or one digit for empty rectangles
        let contentWidth = text.length > 0
            ? text.size(withAttributes: measureAttrs).width
            : monoCharWidth

        var iconWidth = max(contentWidth + padding, baseMinWidth)

        // Enforce minimum width so name-based icons are uniform
        if minIconCharWidth > 0 {
            let prefixWidth = displayStyle == .numbersAndNames ? monoCharWidth * 2 : 0
            iconWidth = max(iconWidth, prefixWidth + monoCharWidth * CGFloat(minIconCharWidth) + padding)
        }

        let size = NSSize(width: iconWidth, height: iconSize.height)

        // 4. Draw the icon
        let iconImage = NSImage(size: size)
        let isActive = space.isCurrentSpace
        let drawRect = NSRect(origin: .zero, size: size)

        iconImage.lockFocus()

        if isBareNumbers {
            // Bare numbers: just text, no box
            let textAlpha: CGFloat = isActive ? 1.0 : Constants.inactiveAlpha
            let textColor = useTemplate ? NSColor.black : boxColor
            text.drawVerticallyCentered(
                in: drawRect,
                withAttributes: getStringAttributes(alpha: textAlpha, color: textColor))
        } else {
            let boxRect = NSRect(origin: .zero, size: size)
                .insetBy(dx: Constants.boxBorderWidth / 2, dy: Constants.boxBorderWidth / 2)
            let cornerRadius = space.isFullScreen ? 0.0 : Constants.boxCornerRadius
            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: cornerRadius, yRadius: cornerRadius)

            if isActive || inactiveStyle == .semiTransparent {
                // Filled box (full opacity for active, reduced for semi-transparent inactive)
                let fillAlpha: CGFloat = isActive ? 1.0 : Constants.inactiveAlpha

                if useTemplate {
                    // Template mode: filled black box, knock out text with destinationOut
                    NSColor.black.withAlphaComponent(fillAlpha).setFill()
                    boxPath.fill()

                    if text.length > 0 {
                        let textImage = NSImage(size: size)
                        textImage.lockFocus()
                        text.drawVerticallyCentered(
                            in: drawRect,
                            withAttributes: getStringAttributes(alpha: 1, color: .black))
                        textImage.unlockFocus()

                        textImage.draw(in: drawRect, from: .zero, operation: .destinationOut, fraction: 1.0)
                    }
                } else {
                    // Colored mode: filled box + contrasting text
                    let effectiveAlpha = boxColor.alphaComponent * fillAlpha
                    boxColor.withAlphaComponent(effectiveAlpha).setFill()
                    boxPath.fill()

                    if text.length > 0 {
                        let textColor = getContrastingTextColor(for: boxColor)
                        text.drawVerticallyCentered(
                            in: drawRect,
                            withAttributes: getStringAttributes(alpha: 1.0, color: textColor))
                    }
                }
            } else {
                // Bordered inactive: bordered outline + text (no fill)
                boxPath.lineWidth = Constants.boxBorderWidth

                if useTemplate {
                    NSColor.black.setStroke()
                    boxPath.stroke()

                    if text.length > 0 {
                        text.drawVerticallyCentered(
                            in: drawRect,
                            withAttributes: getStringAttributes(alpha: 1, color: .black))
                    }
                } else {
                    boxColor.setStroke()
                    boxPath.stroke()

                    if text.length > 0 {
                        text.drawVerticallyCentered(
                            in: drawRect,
                            withAttributes: getStringAttributes(alpha: 1, color: boxColor))
                    }
                }
            }
        }

        iconImage.isTemplate = useTemplate
        iconImage.unlockFocus()

        return iconImage
    }

    /// Create an icon for use in the dropdown menu (StatusBar).
    /// Draws a filled box with the space number at the given opacity.
    public func createMenuItemIcon(space: Space, fraction: CGFloat = 0.6) -> NSImage {
        if sizes == nil {
            sizes = Constants.sizes[layoutMode]
            iconSize = NSSize(
                width: CGFloat(sizes.ICON_WIDTH_SMALL),
                height: CGFloat(sizes.ICON_HEIGHT) + Constants.boxVerticalPadding * 2)
        }

        let text = NSString(string: space.spaceByDesktopID)
        let measureAttrs = getStringAttributes(alpha: 1, color: .black)
        let textSize = text.size(withAttributes: measureAttrs)
        let minWidth = CGFloat(sizes.ICON_WIDTH_SMALL)
        let dynamicWidth = max(textSize.width + Constants.boxPadding * 2, minWidth)
        let size = NSSize(width: dynamicWidth, height: iconSize.height)

        let iconImage = NSImage(size: size)
        let boxRect = NSRect(origin: .zero, size: size)
            .insetBy(dx: Constants.boxBorderWidth / 2, dy: Constants.boxBorderWidth / 2)
        let cornerRadius = space.isFullScreen ? 0.0 : Constants.boxCornerRadius
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let drawRect = NSRect(origin: .zero, size: size)

        iconImage.lockFocus()

        if let colorHex = space.colorHex, let bgColor = NSColor.fromHex(colorHex) {
            bgColor.withAlphaComponent(fraction).setFill()
            boxPath.fill()
            let textColor = getContrastingTextColor(for: bgColor)
            text.drawVerticallyCentered(
                in: drawRect,
                withAttributes: getStringAttributes(alpha: 1, color: textColor))
            iconImage.isTemplate = false
        } else {
            NSColor.black.withAlphaComponent(fraction).setFill()
            boxPath.fill()

            let textImage = NSImage(size: size)
            textImage.lockFocus()
            text.drawVerticallyCentered(
                in: drawRect,
                withAttributes: getStringAttributes(alpha: 1, color: .black))
            textImage.unlockFocus()

            textImage.draw(in: drawRect, from: .zero, operation: .destinationOut, fraction: 1.0)
            iconImage.isTemplate = true
        }

        iconImage.unlockFocus()
        return iconImage
    }

    // MARK: - Display properties and merging

    private func getIconsWithDisplayProps(
        icons: [NSImage],
        spaces: [Space]
    ) -> [(NSImage, Bool, Bool, String, String?)] {
        var iconsWithDisplayProperties =
            [(NSImage, Bool, Bool, String, String?)]()
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
            iconsWithDisplayProperties.append((
                icons[index],
                nextSpaceIsOnDifferentDisplay,
                spaces[index].isFullScreen,
                spaces[index].spaceID,
                spaces[index].colorHex
            ))
        }

        return iconsWithDisplayProperties
    }

    private func mergeIcons(
        _ iconsWithDisplayProperties: [(image: NSImage, nextSpaceOnDifferentDisplay: Bool,
                                        isFullScreen: Bool, spaceID: String, colorHex: String?)],
        indexMap: [String: Int]
    ) -> NSImage {
        let numIcons = iconsWithDisplayProperties.count
        let combinedIconWidth = CGFloat(iconsWithDisplayProperties.reduce(0) { (result, icon) in
            result + icon.image.size.width
        })
        let accomodatingGapWidth = CGFloat(max(0, numIcons - 1)) * gapWidth
        let accomodatingDisplayGapWidth = CGFloat(max(0, displayCount - 1)) * displayGapWidth
        let totalIconWidth = combinedIconWidth + accomodatingGapWidth + accomodatingDisplayGapWidth
        let totalWidth = max(1, totalIconWidth)
        let image = NSImage(size: NSSize(width: totalWidth, height: iconSize.height))

        image.lockFocus()
        var left = CGFloat.zero
        var right: CGFloat
        iconWidths = []

        let hasAnyColoredIcon = iconsWithDisplayProperties.contains { $0.colorHex != nil }

        for icon in iconsWithDisplayProperties {
            icon.image.draw(
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

            let targetIndex = indexMap[icon.spaceID] ?? Space.unswitchableIndex
            iconWidths.append(IconWidth(
                left: iconLeft,
                right: iconRight,
                index: targetIndex
            ))
            left = right
        }
        // Only use template mode if no icons have custom colors
        image.isTemplate = !hasAnyColoredIcon
        image.unlockFocus()

        return image
    }

    private func mergeIconsTwoRows(
        _ iconsWithDisplayProperties: [(image: NSImage, nextSpaceOnDifferentDisplay: Bool,
                                        isFullScreen: Bool, spaceID: String, colorHex: String?)],
        indexMap: [String: Int]
    ) -> NSImage {
        // Column describes a stacked pair (top/bottom)
        // and its rendered width and trailing gap
        struct Column {
            var top: (image: NSImage, isFull: Bool, tag: Int, spaceID: String, colorHex: String?)?
            var bottom: (image: NSImage, isFull: Bool, tag: Int, spaceID: String, colorHex: String?)?
            var width: CGFloat = 0
            var gapAfter: CGFloat = 0
        }

        let assignedIndices: [Int] = iconsWithDisplayProperties.map {
            indexMap[$0.spaceID] ?? Space.unswitchableIndex
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
                    current.top = (
                        icon.image, icon.isFullScreen,
                        tag, icon.spaceID, icon.colorHex
                    )
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = false
                } else {
                    current.bottom = (
                        icon.image, icon.isFullScreen,
                        tag, icon.spaceID, icon.colorHex
                    )
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = true
                }
                let isColumnEnd = placeTop || icon.nextSpaceOnDifferentDisplay
                if isColumnEnd {
                    current.gapAfter = icon.nextSpaceOnDifferentDisplay
                        ? displayGapWidth : gapWidth
                    columns.append(current)
                    current = Column()
                    placeTop = true
                }
                let isLast = idx == iconsWithDisplayProperties.count - 1
                if isLast && (current.top != nil || current.bottom != nil) {
                    current.gapAfter = 0
                    columns.append(current)
                }
            }
        case .byRow:
            // New behavior: fill entire top row left-to-right, then bottom row
            // First, segment by display to place display gaps correctly
            typealias Segment = (
                image: NSImage, nextDisplay: Bool, isFull: Bool,
                tag: Int, spaceID: String, colorHex: String?
            )
            var segments: [[Segment]] = []
            var cur: [Segment] = []
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                cur.append((
                    icon.image, icon.nextSpaceOnDifferentDisplay,
                    icon.isFullScreen, assignedIndices[idx],
                    icon.spaceID, icon.colorHex
                ))
                if icon.nextSpaceOnDifferentDisplay { segments.append(cur); cur = [] }
            }
            if !cur.isEmpty { segments.append(cur) }

            for (segIdx, seg) in segments.enumerated() {
                let count = seg.count
                let topCount = Int(ceil(Double(count) / 2.0))
                let top = Array(seg.prefix(topCount))
                let bottom = Array(seg.dropFirst(topCount))
                let maxLen = max(top.count, bottom.count)
                for i in 0..<maxLen {
                    var col = Column()
                    if i < top.count {
                        let topItem = top[i]
                        col.top = (topItem.image, topItem.isFull, topItem.tag, topItem.spaceID, topItem.colorHex)
                        col.width = max(col.width, topItem.image.size.width)
                    }
                    if i < bottom.count {
                        let bottomItem = bottom[i]
                        col.bottom = (
                            bottomItem.image, bottomItem.isFull,
                            bottomItem.tag, bottomItem.spaceID,
                            bottomItem.colorHex
                        )
                        col.width = max(col.width, bottomItem.image.size.width)
                    }
                    // Add inter-column gap. After the last column of a display,
                    // add display gap (except trailing overall)
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
        let gap = CGFloat(sizes.GAP_HEIGHT_DUALROWS)
        let imageHeight = iconSize.height * 2 + gap
        let image = NSImage(size: NSSize(width: totalWidth, height: imageHeight))

        image.lockFocus()
        var left = CGFloat.zero
        iconWidths = []

        let hasAnyColoredIcon = columns.contains { col in
            (col.top?.colorHex != nil) || (col.bottom?.colorHex != nil)
        }

        for col in columns {
            // Simple gap splitting: each icon owns half the gap on each side
            // (col.gapAfter already accounts for display gaps vs regular gaps)
            let iconLeft = left - (col.gapAfter / 2.0)
            let iconRight = left + col.width + (col.gapAfter / 2.0)

            if let top = col.top {
                top.image.draw(
                    at: NSPoint(x: left, y: iconSize.height + gap),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0)
                iconWidths.append(IconWidth(
                    left: iconLeft,
                    right: iconRight,
                    top: iconSize.height + gap,
                    bottom: imageHeight,
                    index: top.tag))
            }
            if let bottom = col.bottom {
                bottom.image.draw(
                    at: NSPoint(x: left, y: 0),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0)
                iconWidths.append(IconWidth(
                    left: iconLeft,
                    right: iconRight,
                    top: 0,
                    bottom: iconSize.height,
                    index: bottom.tag))
            }
            left += col.width + col.gapAfter
        }
        image.isTemplate = !hasAnyColoredIcon
        image.unlockFocus()
        return image
    }

    // MARK: - Text and color helpers

    private func getStringAttributes(
        alpha: CGFloat,
        fontSize: CGFloat = .zero,
        color: NSColor = .black
    ) -> [NSAttributedString.Key: Any] {
        let actualFontSize = fontSize == .zero ? CGFloat(sizes.FONT_SIZE) : fontSize
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        return [
            .foregroundColor: color.withAlphaComponent(alpha),
            .font: NSFont.monospacedSystemFont(ofSize: actualFontSize, weight: .bold),
            .paragraphStyle: paragraphStyle]
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
