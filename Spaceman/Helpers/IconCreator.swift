//
//  IconCreator.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import AppKit
import Foundation
import SwiftUI

/// A rendered space icon together with the display metadata needed for merging.
struct SpaceIconInfo {
    let image: NSImage
    let nextSpaceOnDifferentDisplay: Bool
    let isFullScreen: Bool
    let spaceID: String
    let colorHex: String?
    let spaceNumber: Int
}

class IconCreator {
    @AppStorage("iconSize") private var iconSize = IconSize.medium
    @AppStorage("displayStyle") private var displayStyle = IconText.numbers
    @AppStorage("rowLayout") private var rowLayout = RowLayout.singleRow
    @AppStorage("visibleSpacesMode") private var visibleSpacesModeRaw: Int = VisibleSpacesMode.all.rawValue
    @AppStorage("neighborRadius") private var neighborRadius = 1
    @AppStorage("decorationActive") private var decorationActive = IconStyle.filledRounded
    @AppStorage("decorationInactive") private var decorationInactive = IconStyle.borderedRounded
    @AppStorage("useVariableWidth") private var useVariableWidth = false
    @AppStorage("fontDesign") private var fontDesign = FontDesign.monospaced
    @AppStorage("showFullscreenSpaces") private var showFullscreenSpaces = true
    @AppStorage("showMissionControl") private var showMissionControl = false
    @AppStorage("showNavArrows") private var showNavArrows = false

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }
    private var displayCount = 1
    private var cellSize = NSSize(width: 0, height: 0)
    private var gapWidth = CGFloat.zero
    private var displayGapWidth = CGFloat.zero
    private var minIconWidth = CGFloat.zero
    private let spaceFilter = SpaceFilter()

    public var sizes: GuiSize!
    public var iconWidths: [IconWidth] = []

    /// Active shrink overrides for the current render pass. Set at the start
    /// of getIcon() and cleared via defer. When non-nil, the `effective*`
    /// computed properties below return overridden values instead of the
    /// @AppStorage user preferences, so all downstream methods automatically
    /// use the shrink settings without parameter threading.
    /// Properties not in ShrinkOverrides (e.g., rowLayout) always use the
    /// user preference — row layout is intentionally never overridden because
    /// two-row mode is more horizontally compact than single-row.
    private var activeShrinkOverrides: ShrinkOverrides?

    private var effectiveIconSize: IconSize { activeShrinkOverrides?.iconSize ?? iconSize }
    private var effectiveDisplayStyle: IconText { activeShrinkOverrides?.displayStyle ?? displayStyle }
    private var effectiveShowFullscreen: Bool { activeShrinkOverrides?.showFullscreenSpaces ?? showFullscreenSpaces }
    private var effectiveShowNavArrows: Bool { activeShrinkOverrides?.showNavArrows ?? showNavArrows }
    private var effectiveShowMissionControl: Bool { activeShrinkOverrides?.showMissionControl ?? showMissionControl }

    public func getIcon(for spaces: [Space], appearance: NSAppearance? = nil,
                        shrinkOverrides: ShrinkOverrides? = nil) -> NSImage {
        activeShrinkOverrides = shrinkOverrides
        defer { activeShrinkOverrides = nil }
        sizes = rowLayout.isTwoRows
            ? Constants.nearestTwoRowSize(for: effectiveIconSize)
            : Constants.sizes[effectiveIconSize]

        let allNoDecoration = decorationActive.isNoDecoration && decorationInactive.isNoDecoration
        let actualFontSize = CGFloat(sizes.FONT_SIZE) + (allNoDecoration ? 2 : 0)
        gapWidth = allNoDecoration ? 0 : CGFloat(sizes.GAP_WIDTH_SPACES)
        displayGapWidth = allNoDecoration ? 0 : CGFloat(sizes.GAP_WIDTH_DISPLAYS)
        cellSize = NSSize(
            width: 0,
            height: actualFontSize + sizes.VERTICAL_PADDING * 2)

        let switchIndexBySpaceID = Space.buildSwitchIndexMap(for: spaces)

        // Determine which spaces to include based on mode
        let filteredSpaces = filterSpaces(spaces)

        // Gracefully handle transient empty state (e.g., during Mission Control updates)
        if filteredSpaces.isEmpty {
            iconWidths = []
            let empty = NSImage(size: NSSize(width: 1, height: cellSize.height))
            empty.isTemplate = true
            return empty
        }

        // For uniform icon widths: find the widest text and use it as the minimum width for all icons.
        // In single-row mode, this only applies to name-based styles (names, numbers+names).
        // In two-row mode, numbers-only also gets equalized — without it, "1" and "10" would have
        // visibly different widths, making the two-row grid look uneven.
        let showsNames = effectiveDisplayStyle == .names || effectiveDisplayStyle == .numbersAndNames
        let maxNameChars = rowLayout.isTwoRows ? 8 : 4
        let equalizeNumbers = rowLayout.isTwoRows && effectiveDisplayStyle == .numbers
        if !useVariableWidth && (showsNames || equalizeNumbers) {
            let measureAttrs = getStringAttributes(alpha: 1, color: .black)
            let padding = sizes.HORIZONTAL_PADDING * 2
            minIconWidth = filteredSpaces.filter { !$0.isFullScreen }.reduce(CGFloat.zero) { widest, space in
                // Build the same text string that createSpaceIcon() will render,
                // so the width measurement matches the actual content.
                let text: NSString
                if equalizeNumbers {
                    text = NSString(string: space.spaceByDesktopID)
                } else if effectiveDisplayStyle == .numbersAndNames {
                    let cappedName = String(space.spaceName.prefix(min(maxNameChars, Constants.maxSpaceNameLength)))
                    text = NSString(string: "\(space.spaceByDesktopID):\(cappedName)")
                } else {
                    text = NSString(
                        string: String(space.spaceName.prefix(min(maxNameChars, Constants.maxSpaceNameLength)))
                    )
                }
                let textWidth = text.size(withAttributes: measureAttrs).width
                return max(widest, textWidth + padding)
            }
        } else {
            minIconWidth = 0
        }

        // Pre-scan for mixed color context: when some spaces have custom colors,
        // non-colored spaces get a default color instead of template mode
        let hasAnyColoredSpace = filteredSpaces.contains { $0.colorHex != nil }
        let defaultColor: NSColor? = hasAnyColoredSpace ? getDefaultColorForAppearance(appearance) : nil

        // Create icons using unified box rendering
        let icons = filteredSpaces.map { space in
            createSpaceIcon(space: space, defaultColor: defaultColor)
        }

        // Nav icons use the current cellSize (matching one row height in two-row mode)
        let navIcons = createNavigationIcons(defaultColor: defaultColor)
        let iconsWithDisplayProperties = getIconsWithDisplayProps(icons: icons, spaces: filteredSpaces)
        if rowLayout.isTwoRows {
            return mergeIconsTwoRows(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID,
                                        spaces: filteredSpaces, defaultColor: defaultColor,
                                        navIcons: navIcons)
        } else {
            return mergeIcons(iconsWithDisplayProperties, indexMap: switchIndexBySpaceID,
                              navIcons: navIcons)
        }
    }

    private func filterSpaces(_ spaces: [Space]) -> [Space] {
        var result = spaceFilter.filter(spaces, mode: visibleSpacesMode, neighborRadius: neighborRadius)
        if !effectiveShowFullscreen {
            result = result.filter { !$0.isFullScreen }
        }
        return result
    }

    // MARK: - Unified box rendering

    private func createSpaceIcon(space: Space, defaultColor: NSColor?, minWidth: CGFloat = 0) -> NSImage {
        // 1. Determine text content based on display style
        let text: NSString
        switch effectiveDisplayStyle {
        case .noText:
            text = ""
        case .numbers:
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

        // 3. Determine decoration for this space
        let isActive = space.isCurrentSpace
        let baseIconStyle = isActive ? decorationActive : decorationInactive
        let decoration = space.isFullScreen ? baseIconStyle.fullscreenVariant : baseIconStyle
        let shouldDim = !isActive && decorationActive == decorationInactive
        let alpha: CGFloat = shouldDim ? Constants.inactiveAlpha : 1.0

        // 4. Calculate icon size (dynamic width based on text)
        let measureAttrs = getStringAttributes(alpha: 1, color: .black)
        let monoCharWidth = ("0" as NSString).size(withAttributes: measureAttrs).width
        let padding = sizes.HORIZONTAL_PADDING * 2

        let contentWidth = text.length > 0
            ? text.size(withAttributes: measureAttrs).width
            : monoCharWidth

        var iconWidth = contentWidth + padding

        if minIconWidth > 0 && !space.spaceID.hasPrefix("nav-") {
            iconWidth = max(iconWidth, minIconWidth)
        }
        if minWidth > 0 {
            iconWidth = max(iconWidth, minWidth)
        }

        let fontWeight: NSFont.Weight = !isActive && rowLayout.isTwoRows ? .medium : .bold
        let size = NSSize(width: iconWidth, height: cellSize.height)
        return renderIcon(
            text: text, size: size, decoration: decoration,
            boxColor: boxColor, useTemplate: useTemplate,
            alpha: alpha, borderWidth: sizes.BORDER_WIDTH,
            fontWeight: fontWeight)
    }

    /// Create an icon for use in the dropdown menu (StatusBar).
    /// Always uses medium layout sizing but mirrors the active icon style.
    public func createMenuItemIcon(space: Space, fraction: CGFloat = 0.6) -> NSImage {
        guard let menuSizes = Constants.sizes[.medium] else { return NSImage() }
        let menuFontSize = CGFloat(menuSizes.FONT_SIZE)
        let menuHeight = menuFontSize + menuSizes.VERTICAL_PADDING * 2

        let decoration = space.isFullScreen ? decorationActive.fullscreenVariant : decorationActive

        let boxColor: NSColor
        let useTemplate: Bool
        if let colorHex = space.colorHex, let customColor = NSColor.fromHex(colorHex) {
            boxColor = customColor
            useTemplate = false
        } else {
            boxColor = .black
            useTemplate = true
        }

        let text = NSString(string: space.spaceByDesktopID)
        let measureAttrs = getStringAttributes(alpha: 1, fontSize: menuFontSize, color: .black)
        let dynamicWidth = text.size(withAttributes: measureAttrs).width + menuSizes.HORIZONTAL_PADDING * 2
        let size = NSSize(width: dynamicWidth, height: menuHeight)

        return renderIcon(
            text: text, size: size, decoration: decoration,
            boxColor: boxColor, useTemplate: useTemplate,
            alpha: fraction, borderWidth: menuSizes.BORDER_WIDTH,
            fontSize: menuFontSize)
    }

    // MARK: - Icon rendering

    // All parameters are distinct, required values for one rendering operation.
    // A wrapper struct would add boilerplate without improving readability.
    // swiftlint:disable:next function_parameter_count
    private func renderIcon(
        text: NSString,
        size: NSSize,
        decoration: IconStyle,
        boxColor: NSColor,
        useTemplate: Bool,
        alpha: CGFloat,
        borderWidth: CGFloat,
        fontSize: CGFloat = .zero,
        fontWeight: NSFont.Weight = .bold
    ) -> NSImage {
        let iconImage = NSImage(size: size)
        let drawRect = NSRect(origin: .zero, size: size)

        iconImage.lockFocus()

        if decoration.isNoDecoration {
            let textColor = useTemplate ? NSColor.black : boxColor
            text.drawVerticallyCentered(
                in: drawRect,
                withAttributes: getStringAttributes(alpha: alpha, fontSize: fontSize, color: textColor,
                                                    weight: fontWeight))
        } else if decoration.isFilled {
            let boxRect = drawRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            let cornerRadius = decoration.cornerRadius(for: boxRect)
            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: cornerRadius, yRadius: cornerRadius)

            if useTemplate {
                NSColor.black.withAlphaComponent(alpha).setFill()
                boxPath.fill()

                if text.length > 0 {
                    let textImage = NSImage(size: size)
                    textImage.lockFocus()
                    text.drawVerticallyCentered(
                        in: drawRect,
                        withAttributes: getStringAttributes(alpha: 1, fontSize: fontSize, color: .black,
                                                            weight: fontWeight))
                    textImage.unlockFocus()

                    textImage.draw(in: drawRect, from: .zero, operation: .destinationOut, fraction: 1.0)
                }
            } else {
                let effectiveAlpha = boxColor.alphaComponent * alpha
                boxColor.withAlphaComponent(effectiveAlpha).setFill()
                boxPath.fill()

                if text.length > 0 {
                    let textColor = getContrastingTextColor(for: boxColor)
                    text.drawVerticallyCentered(
                        in: drawRect,
                        withAttributes: getStringAttributes(alpha: 1.0, fontSize: fontSize, color: textColor,
                                                            weight: fontWeight))
                }
            }
        } else {
            // Bordered: outline + text (no fill)
            let boxRect = drawRect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            let cornerRadius = decoration.cornerRadius(for: boxRect)
            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: cornerRadius, yRadius: cornerRadius)
            boxPath.lineWidth = borderWidth

            if useTemplate {
                NSColor.black.withAlphaComponent(alpha).setStroke()
                boxPath.stroke()

                if text.length > 0 {
                    text.drawVerticallyCentered(
                        in: drawRect,
                        withAttributes: getStringAttributes(alpha: alpha, fontSize: fontSize, color: .black,
                                                            weight: fontWeight))
                }
            } else {
                boxColor.withAlphaComponent(alpha).setStroke()
                boxPath.stroke()

                if text.length > 0 {
                    text.drawVerticallyCentered(
                        in: drawRect,
                        withAttributes: getStringAttributes(alpha: alpha, fontSize: fontSize, color: boxColor,
                                                            weight: fontWeight))
                }
            }
        }

        iconImage.isTemplate = useTemplate
        iconImage.unlockFocus()

        return iconImage
    }

    // MARK: - Navigation icons (arrows + Mission Control)

    private func makeNavSpace(label: String) -> Space {
        Space(displayID: "", spaceID: "nav-\(label)", spaceName: label,
              spaceNumber: 0, spaceByDesktopID: label,
              isCurrentSpace: false, isFullScreen: false)
    }

    /// Mission Control icon: square box with two small rects left, one tall rect right.
    /// Reuses createSpaceIcon for the decoration box, then composites the symbol on top.
    private func createMissionControlIcon(defaultColor: NSColor?, minWidth: CGFloat = 0) -> NSImage {
        let h = cellSize.height
        let boxWidth = max(h, minWidth)
        let box = createSpaceIcon(space: makeNavSpace(label: " "), defaultColor: defaultColor, minWidth: boxWidth)
        let size = box.size
        let inset = h * 0.25
        let gap: CGFloat = 1.25
        let innerW = h - inset * 2
        let rightW = (innerW - gap) / 2
        let leftW = (innerW - gap) / 1.8
        let squareOriginX = (size.width - 2 * inset - leftW - rightW) / 2  // center the staggered symbol horizontally
        let inner = NSRect(x: squareOriginX + inset, y: inset, width: innerW, height: h - inset * 2)
        let smallH = (inner.height - gap) / 2

        let shouldDim = decorationActive == decorationInactive
        let alpha: CGFloat = shouldDim ? Constants.inactiveAlpha : 1.0
        let symbolColor: NSColor
        if box.isTemplate {
            // Template mode: macOS handles color inversion; alpha for dimming
            symbolColor = NSColor.black.withAlphaComponent(alpha)
        } else if decorationInactive.isFilled {
            // Filled + colored: text at full opacity (same as renderIcon line 270)
            symbolColor = getContrastingTextColor(for: defaultColor ?? .black)
        } else {
            // Bordered + colored: text matches border, dimmed
            symbolColor = (defaultColor ?? .black).withAlphaComponent(alpha)
        }

        let symbol = NSImage(size: size)
        symbol.lockFocus()
        symbolColor.setFill()
        let shift: CGFloat = gap
        // Top-left small rect (shifted left)
        NSBezierPath(
            roundedRect: NSRect(
                x: inner.minX - shift,
                y: inner.minY + smallH + gap,
                width: leftW,
                height: smallH
            ),
            xRadius: 0.5,
            yRadius: 0.5
        ).fill()
        // Bottom-left small rect (original position)
        NSBezierPath(
            roundedRect: NSRect(
                x: inner.minX,
                y: inner.minY,
                width: leftW,
                height: smallH
            ),
            xRadius: 0.5,
            yRadius: 0.5
        ).fill()
        // Right tall rect (cropped at the bottom)
        NSBezierPath(
            roundedRect: NSRect(
                x: inner.minX + leftW + gap,
                y: inner.minY + shift,
                width: rightW,
                height: inner.height - shift
            ),
            xRadius: 0.5,
            yRadius: 0.5
        ).fill()
        symbol.unlockFocus()

        box.lockFocus()
        let op: NSCompositingOperation = (decorationInactive.isFilled && box.isTemplate) ? .destinationOut : .sourceOver
        symbol.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: op, fraction: 1.0)
        box.unlockFocus()
        return box
    }

    /// Returns navigation icons based on the current settings.
    private func createNavigationIcons(defaultColor: NSColor?) -> [(image: NSImage, index: Int)] {
        var result: [(image: NSImage, index: Int)] = []
        var arrowIcon: NSImage?
        if effectiveShowNavArrows {
            let left = createSpaceIcon(space: makeNavSpace(label: "◀"), defaultColor: defaultColor)
            arrowIcon = left
            result.append((left, Space.previousSpaceIndex))
        }
        if effectiveShowMissionControl {
            let mcMinWidth: CGFloat
            if rowLayout.isTwoRows, let aw = arrowIcon?.size.width {
                // In two-row mode: MC spans the full width of both arrows + gap
                mcMinWidth = aw * 2 + gapWidth
            } else if !useVariableWidth, let aw = arrowIcon?.size.width {
                mcMinWidth = aw
            } else {
                mcMinWidth = 0
            }
            result.append((createMissionControlIcon(defaultColor: defaultColor, minWidth: mcMinWidth),
                Space.missionControlIndex))
        }
        if effectiveShowNavArrows {
            result.append((createSpaceIcon(
                space: makeNavSpace(label: "▶"), defaultColor: defaultColor),
                Space.nextSpaceIndex))
        }
        return result
    }

    /// Draw navigation icons and append their hit-test entries.
    /// Call within a lockFocus context. Returns the updated left position.
    private func drawNavIcons(
        _ navIcons: [(image: NSImage, index: Int)],
        at y: CGFloat,
        left: CGFloat
    ) -> CGFloat {
        var left = left
        for (idx, nav) in navIcons.enumerated() {
            nav.image.draw(
                at: NSPoint(x: left, y: y),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0)
            let isLast = idx == navIcons.count - 1
            let gap = isLast ? displayGapWidth : gapWidth
            let iconLeft = left - (gap / 2.0)
            let iconRight = left + nav.image.size.width + (gap / 2.0)
            // Nav icons use no vertical bounds (Y ignored in hit testing)
            iconWidths.append(IconWidth(
                left: iconLeft,
                right: iconRight,
                index: nav.index
            ))
            left += nav.image.size.width + gap
        }
        return left
    }

    // MARK: - Display properties and merging

    private func getIconsWithDisplayProps(
        icons: [NSImage],
        spaces: [Space]
    ) -> [SpaceIconInfo] {
        var iconsWithDisplayProperties = [SpaceIconInfo]()
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
            iconsWithDisplayProperties.append(SpaceIconInfo(
                image: icons[index],
                nextSpaceOnDifferentDisplay: nextSpaceIsOnDifferentDisplay,
                isFullScreen: spaces[index].isFullScreen,
                spaceID: spaces[index].spaceID,
                colorHex: spaces[index].colorHex,
                spaceNumber: spaces[index].spaceNumber
            ))
        }

        return iconsWithDisplayProperties
    }

    private func mergeIcons(
        _ iconsWithDisplayProperties: [SpaceIconInfo],
        indexMap: [String: Int],
        navIcons: [(image: NSImage, index: Int)]
    ) -> NSImage {
        let numIcons = iconsWithDisplayProperties.count
        let combinedIconWidth = CGFloat(iconsWithDisplayProperties.reduce(0) { (result, icon) in
            result + icon.image.size.width
        })
        let accomodatingGapWidth = CGFloat(max(0, numIcons - 1)) * gapWidth
        let accomodatingDisplayGapWidth = CGFloat(max(0, displayCount - 1)) * displayGapWidth
        let navWidth = navIcons.reduce(CGFloat(0)) { $0 + $1.image.size.width }
        let navGaps = navIcons.isEmpty ? 0 : CGFloat(max(0, navIcons.count - 1)) * gapWidth + displayGapWidth
        let totalIconWidth = navWidth + navGaps + combinedIconWidth + accomodatingGapWidth + accomodatingDisplayGapWidth
        let totalWidth = max(1, totalIconWidth)
        let image = NSImage(size: NSSize(width: totalWidth, height: cellSize.height))

        image.lockFocus()
        var left = CGFloat.zero
        iconWidths = []

        let hasAnyColoredIcon = iconsWithDisplayProperties.contains { $0.colorHex != nil }

        left = drawNavIcons(navIcons, at: 0, left: left)

        // Draw space icons
        var right: CGFloat
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
                index: targetIndex,
                spaceNumber: icon.spaceNumber
            ))
            left = right
        }
        // Only use template mode if no icons have custom colors
        image.isTemplate = !hasAnyColoredIcon
        image.unlockFocus()

        return image
    }

    private func mergeIconsTwoRows(
        _ iconsWithDisplayProperties: [SpaceIconInfo],
        indexMap: [String: Int],
        spaces: [Space],
        defaultColor: NSColor?,
        navIcons: [(image: NSImage, index: Int)]
    ) -> NSImage {
        // Column describes a stacked pair (top/bottom)
        // and its rendered width and trailing gap
        struct Column {
            var top: (image: NSImage, isFull: Bool, tag: Int, spaceID: String, colorHex: String?, spaceNumber: Int)?
            var bottom: (image: NSImage, isFull: Bool, tag: Int, spaceID: String, colorHex: String?, spaceNumber: Int)?
            var width: CGFloat = 0
            var gapAfter: CGFloat = 0
        }

        let assignedIndices: [Int] = iconsWithDisplayProperties.map {
            indexMap[$0.spaceID] ?? Space.unswitchableIndex
        }

        // Build columns depending on fill order preference
        var columns: [Column] = []
        switch rowLayout {
        case .twoRowsByColumn, .singleRow:
            // Original behavior: fill top then bottom per column
            var current = Column()
            var placeTop = true
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                let tag = assignedIndices[idx]
                if placeTop {
                    current.top = (
                        icon.image, icon.isFullScreen,
                        tag, icon.spaceID, icon.colorHex,
                        icon.spaceNumber
                    )
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = false
                } else {
                    current.bottom = (
                        icon.image, icon.isFullScreen,
                        tag, icon.spaceID, icon.colorHex,
                        icon.spaceNumber
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
        case .twoRowsByRow:
            // New behavior: fill entire top row left-to-right, then bottom row
            // First, segment by display to place display gaps correctly
            typealias Segment = (
                image: NSImage, nextDisplay: Bool, isFull: Bool,
                tag: Int, spaceID: String, colorHex: String?,
                spaceNumber: Int
            )
            var segments: [[Segment]] = []
            var cur: [Segment] = []
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                cur.append((
                    icon.image, icon.nextSpaceOnDifferentDisplay,
                    icon.isFullScreen, assignedIndices[idx],
                    icon.spaceID, icon.colorHex,
                    icon.spaceNumber
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
                        col.top = (
                            topItem.image,
                            topItem.isFull,
                            topItem.tag,
                            topItem.spaceID,
                            topItem.colorHex,
                            topItem.spaceNumber
                        )
                        col.width = max(col.width, topItem.image.size.width)
                    }
                    if i < bottom.count {
                        let bottomItem = bottom[i]
                        col.bottom = (
                            bottomItem.image, bottomItem.isFull,
                            bottomItem.tag, bottomItem.spaceID,
                            bottomItem.colorHex, bottomItem.spaceNumber
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

        // Equalize icon widths within each column by re-rendering the narrower icon at column width;
        // this achieves simplicity by keeping all pairing logic in one place and avoids a complex pre-computation pass
        let spacesByID = Dictionary(spaces.map { ($0.spaceID, $0) }, uniquingKeysWith: { first, _ in first })
        for i in 0..<columns.count {
            let colWidth = columns[i].width
            if let top = columns[i].top, top.image.size.width < colWidth,
               let space = spacesByID[top.spaceID] {
                let newImage = createSpaceIcon(space: space, defaultColor: defaultColor, minWidth: colWidth)
                columns[i].top = (newImage, top.isFull, top.tag, top.spaceID, top.colorHex, top.spaceNumber)
            }
            if let bottom = columns[i].bottom, bottom.image.size.width < colWidth,
               let space = spacesByID[bottom.spaceID] {
                let newImage = createSpaceIcon(space: space, defaultColor: defaultColor, minWidth: colWidth)
                columns[i].bottom = (
                    newImage,
                    bottom.isFull,
                    bottom.tag,
                    bottom.spaceID,
                    bottom.colorHex,
                    bottom.spaceNumber
                )
            }
        }

        // Render
        let topNavIcons = navIcons.filter { $0.index != Space.missionControlIndex }
        let bottomNavIcons = navIcons.filter { $0.index == Space.missionControlIndex }
        let topNavWidth = topNavIcons.reduce(CGFloat(0)) { $0 + $1.image.size.width }
            + CGFloat(max(0, topNavIcons.count - 1)) * gapWidth
        let bottomNavWidth = bottomNavIcons.reduce(CGFloat(0)) { $0 + $1.image.size.width }
        let navColWidth = max(topNavWidth, bottomNavWidth)
        let navTotal = navIcons.isEmpty ? 0 : navColWidth + displayGapWidth
        let totalWidth = navTotal + columns.reduce(CGFloat(0)) { $0 + $1.width + $1.gapAfter }
        let gap = sizes.GAP_HEIGHT_ROWS
        let imageHeight = cellSize.height * 2 + gap
        let image = NSImage(size: NSSize(width: totalWidth, height: imageHeight))

        image.lockFocus()
        var left = CGFloat.zero
        iconWidths = []

        let hasAnyColoredIcon = columns.contains { col in
            (col.top?.colorHex != nil) || (col.bottom?.colorHex != nil)
        }

        // Draw nav icons: arrows on top row, MC on bottom (or top if no arrows)
        let midGap = cellSize.height + gap / 2.0
        if !navIcons.isEmpty {
            if topNavIcons.isEmpty {
                // No arrows: MC goes on top row
                for nav in bottomNavIcons {
                    nav.image.draw(at: NSPoint(x: left, y: cellSize.height + gap),
                                   from: .zero, operation: .sourceOver, fraction: 1.0)
                    iconWidths.append(IconWidth(left: left, right: left + nav.image.size.width,
                                                index: nav.index))
                }
            } else {
                // Arrows on top row
                var topLeft = left
                for (idx, nav) in topNavIcons.enumerated() {
                    nav.image.draw(at: NSPoint(x: topLeft, y: cellSize.height + gap),
                                   from: .zero, operation: .sourceOver, fraction: 1.0)
                    let navGap = idx < topNavIcons.count - 1 ? gapWidth : CGFloat(0)
                    let iconLeft = topLeft - (navGap / 2.0)
                    let iconRight = topLeft + nav.image.size.width + (navGap / 2.0)
                    iconWidths.append(IconWidth(left: iconLeft, right: iconRight,
                                                top: midGap, bottom: imageHeight * 2, index: nav.index))
                    topLeft += nav.image.size.width + navGap
                }
                // MC on bottom row, centered
                for nav in bottomNavIcons {
                    let mcX = left + (navColWidth - nav.image.size.width) / 2.0
                    nav.image.draw(at: NSPoint(x: mcX, y: 0),
                                   from: .zero, operation: .sourceOver, fraction: 1.0)
                    iconWidths.append(IconWidth(left: left, right: left + navColWidth,
                                                top: -imageHeight, bottom: midGap, index: nav.index))
                }
            }
            left += navColWidth + displayGapWidth
        }

        // Split vertical hit area at the gap midpoint; extend bounds generously
        // to cover menu bar padding above/below the image

        for col in columns {
            // Simple gap splitting: each icon owns half the gap on each side
            // (col.gapAfter already accounts for display gaps vs regular gaps)
            let iconLeft = left - (col.gapAfter / 2.0)
            let iconRight = left + col.width + (col.gapAfter / 2.0)

            if let top = col.top {
                top.image.draw(
                    at: NSPoint(x: left, y: cellSize.height + gap),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0)
                iconWidths.append(IconWidth(
                    left: iconLeft,
                    right: iconRight,
                    top: midGap,
                    bottom: imageHeight * 2,
                    index: top.tag,
                    spaceNumber: top.spaceNumber))
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
                    top: -imageHeight,
                    bottom: midGap,
                    index: bottom.tag,
                    spaceNumber: bottom.spaceNumber))
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
        color: NSColor = .black,
        design: NSFontDescriptor.SystemDesign? = nil,
        weight: NSFont.Weight = .bold
    ) -> [NSAttributedString.Key: Any] {
        let design = design ?? fontDesign.systemDesign
        let allNoDecoration = decorationActive.isNoDecoration && decorationInactive.isNoDecoration
        let baseFontSize = CGFloat(sizes.FONT_SIZE) + (allNoDecoration ? 2 : 0)
        let actualFontSize = fontSize == .zero ? baseFontSize : fontSize
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let base = NSFont.systemFont(ofSize: actualFontSize, weight: weight)
        let font: NSFont
        if let descriptor = base.fontDescriptor.withDesign(design),
           let designFont = NSFont(descriptor: descriptor, size: actualFontSize) {
            font = designFont
        } else {
            font = base
        }
        return [
            .foregroundColor: color.withAlphaComponent(alpha),
            .font: font,
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

    private func getContrastingTextColor(for backgroundColor: NSColor) -> NSColor {
        backgroundColor.contrastingTextColor
    }
}
