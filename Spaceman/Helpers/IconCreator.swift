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

    public func getIcon(for spaces: [Space], appearance: NSAppearance? = nil) -> NSImage {
        sizes = rowLayout.isTwoRows
            ? Constants.nearestTwoRowSize(for: iconSize)
            : Constants.sizes[iconSize]

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

        // For uniform icon widths: measure the widest rendered name, capped for compactness
        let showsNames = displayStyle == .names || displayStyle == .numbersAndNames
        let maxNameChars = rowLayout.isTwoRows ? 8 : 4
        if !useVariableWidth && showsNames {
            let measureAttrs = getStringAttributes(alpha: 1, color: .black)
            let padding = sizes.HORIZONTAL_PADDING * 2
            minIconWidth = filteredSpaces.filter { !$0.isFullScreen }.reduce(CGFloat.zero) { widest, space in
                let cappedName = String(space.spaceName.prefix(min(maxNameChars, Constants.maxSpaceNameLength)))
                let nameText: NSString
                if displayStyle == .numbersAndNames {
                    nameText = NSString(string: "\(space.spaceByDesktopID):\(cappedName)")
                } else {
                    nameText = NSString(string: cappedName)
                }
                let textWidth = nameText.size(withAttributes: measureAttrs).width
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

        // Nav icons always use single-row sizes and height
        let savedSizes = sizes
        let savedCellSize = cellSize
        if rowLayout.isTwoRows {
            sizes = Constants.sizes[iconSize]
            let allNoDecoration = decorationActive.isNoDecoration && decorationInactive.isNoDecoration
            let actualFontSize = CGFloat(sizes.FONT_SIZE) + (allNoDecoration ? 2 : 0)
            cellSize = NSSize(width: 0, height: actualFontSize + sizes.VERTICAL_PADDING * 2)
        }
        let navIcons = createNavigationIcons(defaultColor: defaultColor)
        sizes = savedSizes
        cellSize = savedCellSize
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
        if !showFullscreenSpaces {
            result = result.filter { !$0.isFullScreen }
        }
        return result
    }

    // MARK: - Unified box rendering

    private func createSpaceIcon(space: Space, defaultColor: NSColor?, minWidth: CGFloat = 0) -> NSImage {
        // 1. Determine text content based on display style
        let text: NSString
        switch displayStyle {
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

        let size = NSSize(width: iconWidth, height: cellSize.height)
        return renderIcon(
            text: text, size: size, decoration: decoration,
            boxColor: boxColor, useTemplate: useTemplate,
            alpha: alpha, borderWidth: sizes.BORDER_WIDTH)
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
        fontSize: CGFloat = .zero
    ) -> NSImage {
        let iconImage = NSImage(size: size)
        let drawRect = NSRect(origin: .zero, size: size)

        iconImage.lockFocus()

        if decoration.isNoDecoration {
            let textColor = useTemplate ? NSColor.black : boxColor
            text.drawVerticallyCentered(
                in: drawRect,
                withAttributes: getStringAttributes(alpha: alpha, fontSize: fontSize, color: textColor))
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
                        withAttributes: getStringAttributes(alpha: 1, fontSize: fontSize, color: .black))
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
                        withAttributes: getStringAttributes(alpha: 1.0, fontSize: fontSize, color: textColor))
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
                        withAttributes: getStringAttributes(alpha: alpha, fontSize: fontSize, color: .black))
                }
            } else {
                boxColor.withAlphaComponent(alpha).setStroke()
                boxPath.stroke()

                if text.length > 0 {
                    text.drawVerticallyCentered(
                        in: drawRect,
                        withAttributes: getStringAttributes(alpha: alpha, fontSize: fontSize, color: boxColor))
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
        let squareOriginX = (size.width - h) / 2  // center the square area horizontally
        let inner = NSRect(x: squareOriginX + inset, y: inset, width: h - inset * 2, height: h - inset * 2)
        let gap: CGFloat = 1.5
        let colW = (inner.width - gap) / 2
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
        NSBezierPath(roundedRect: NSRect(x: inner.minX, y: inner.minY + smallH + gap,
                                         width: colW, height: smallH), xRadius: 0.5, yRadius: 0.5).fill()
        NSBezierPath(roundedRect: NSRect(x: inner.minX, y: inner.minY,
                                         width: colW, height: smallH), xRadius: 0.5, yRadius: 0.5).fill()
        NSBezierPath(roundedRect: NSRect(x: inner.minX + colW + gap, y: inner.minY,
                                         width: colW, height: inner.height), xRadius: 0.5, yRadius: 0.5).fill()
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
        if showNavArrows {
            let left = createSpaceIcon(space: makeNavSpace(label: "◀"), defaultColor: defaultColor)
            arrowIcon = left
            result.append((left, Space.previousSpaceIndex))
        }
        if showMissionControl {
            let minWidth = (!useVariableWidth && arrowIcon != nil) ? arrowIcon?.size.width ?? 0 : 0
            result.append((createMissionControlIcon(defaultColor: defaultColor, minWidth: minWidth),
                Space.missionControlIndex))
        }
        if showNavArrows {
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
        indexMap: [String: Int],
        spaces: [Space],
        defaultColor: NSColor?,
        navIcons: [(image: NSImage, index: Int)]
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
        case .twoRowsByRow:
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

        // Equalize icon widths within each column by re-rendering the narrower icon at column width;
        // this achieves simplicity by keeping all pairing logic in one place and avoids a complex pre-computation pass
        let spacesByID = Dictionary(spaces.map { ($0.spaceID, $0) }, uniquingKeysWith: { first, _ in first })
        for i in 0..<columns.count {
            let colWidth = columns[i].width
            if let top = columns[i].top, top.image.size.width < colWidth,
               let space = spacesByID[top.spaceID] {
                let newImage = createSpaceIcon(space: space, defaultColor: defaultColor, minWidth: colWidth)
                columns[i].top = (newImage, top.isFull, top.tag, top.spaceID, top.colorHex)
            }
            if let bottom = columns[i].bottom, bottom.image.size.width < colWidth,
               let space = spacesByID[bottom.spaceID] {
                let newImage = createSpaceIcon(space: space, defaultColor: defaultColor, minWidth: colWidth)
                columns[i].bottom = (newImage, bottom.isFull, bottom.tag, bottom.spaceID, bottom.colorHex)
            }
        }

        // Render
        let navWidth = navIcons.reduce(CGFloat(0)) { $0 + $1.image.size.width }
        let navGaps = navIcons.isEmpty ? 0 : CGFloat(max(0, navIcons.count - 1)) * gapWidth + displayGapWidth
        let totalWidth = navWidth + navGaps + columns.reduce(CGFloat(0)) { $0 + $1.width + $1.gapAfter }
        let gap = sizes.GAP_HEIGHT_ROWS
        let imageHeight = cellSize.height * 2 + gap
        let image = NSImage(size: NSSize(width: totalWidth, height: imageHeight))

        image.lockFocus()
        var left = CGFloat.zero
        iconWidths = []

        let hasAnyColoredIcon = columns.contains { col in
            (col.top?.colorHex != nil) || (col.bottom?.colorHex != nil)
        }

        let navIconHeight = navIcons.first?.image.size.height ?? cellSize.height
        let navY = (imageHeight - navIconHeight) / 2.0
        left = drawNavIcons(navIcons, at: navY, left: left)

        // Split vertical hit area at the gap midpoint; extend bounds generously
        // to cover menu bar padding above/below the image
        let midGap = cellSize.height + gap / 2.0

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
                    top: -imageHeight,
                    bottom: midGap,
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
        color: NSColor = .black,
        design: NSFontDescriptor.SystemDesign? = nil
    ) -> [NSAttributedString.Key: Any] {
        let design = design ?? fontDesign.systemDesign
        let allNoDecoration = decorationActive.isNoDecoration && decorationInactive.isNoDecoration
        let baseFontSize = CGFloat(sizes.FONT_SIZE) + (allNoDecoration ? 2 : 0)
        let actualFontSize = fontSize == .zero ? baseFontSize : fontSize
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let base = NSFont.systemFont(ofSize: actualFontSize, weight: .bold)
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
