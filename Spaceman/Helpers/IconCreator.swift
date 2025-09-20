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
    @AppStorage("hideInactiveSpaces") private var hideInactiveSpaces = false
    @AppStorage("dualRowFillOrder") private var dualRowFillOrder = DualRowFillOrder.columnMajor
    
    private let leftMargin = CGFloat(7)  /* FIXME determine actual left margin */
    private var displayCount = 1
    private var iconSize = NSSize(width: 0, height: 0)
    private var gapWidth = CGFloat.zero
    private var displayGapWidth = CGFloat.zero

    public var sizes: GuiSize!
    public var iconWidths: [IconWidth] = []

    public func getIcon(for spaces: [Space]) -> NSImage {
        sizes = Constants.sizes[layoutMode]
        gapWidth = CGFloat(sizes.GAP_WIDTH_SPACES)
        displayGapWidth = CGFloat(sizes.GAP_WIDTH_DISPLAYS)
        iconSize = NSSize(
            width: sizes.ICON_WIDTH_SMALL,
            height: sizes.ICON_HEIGHT)
        
        var icons = [NSImage]()
        
        for s in spaces {
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
            case (true, false, _):
                iconResourceName = "SpaceIconNumNormalActive"
            default:
                // (true, true, .numbersAndNames)
                // (false, true, .numbersAndNames)
                iconResourceName = "SpaceIconNumNormalInactive"
            }
            
            icons.append(NSImage(imageLiteralResourceName: iconResourceName))
        }
        
        switch displayStyle {
        case .rects:
            //icons = resizeIcons(spaces, icons, layoutMode)
            break
        case .numbers:
            icons = createNumberedIcons(spaces)
        case .numbersAndRects:
            icons = createRectWithNumbersIcons(icons, spaces)
        case .names, .numbersAndNames:
            icons = createNamedIcons(icons, spaces, withNumbers: displayStyle == .numbersAndNames)
        }
        
        let iconsWithDisplayProperties = getIconsWithDisplayProps(icons: icons, spaces: spaces)
        if layoutMode == .dualRows {
            return mergeIconsTwoRows(iconsWithDisplayProperties)
        } else {
            return mergeIcons(iconsWithDisplayProperties)
        }
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
            let spaceText = NSString(string: "\(spaceNumberPrefix)\(s.spaceName.uppercased())")
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
    
    private func getIconsWithDisplayProps(icons: [NSImage], spaces: [Space]) -> [(NSImage, Bool, Bool)] {
        var iconsWithDisplayProperties = [(NSImage, Bool, Bool)]()
        var currentDisplayID = spaces[0].displayID
        displayCount = 1
        
        for index in 0 ..< spaces.count {
            if hideInactiveSpaces && !spaces[index].isCurrentSpace {
                continue
            }
            
            var nextSpaceIsOnDifferentDisplay = false
            
            if !hideInactiveSpaces && index + 1 < spaces.count {
                let thisDisplayID = spaces[index + 1].displayID
                if thisDisplayID != currentDisplayID {
                    currentDisplayID = thisDisplayID
                    displayCount += 1
                    nextSpaceIsOnDifferentDisplay = true
                }
            }
            
            iconsWithDisplayProperties.append((icons[index], nextSpaceIsOnDifferentDisplay, spaces[index].isFullScreen))
        }
        
        return iconsWithDisplayProperties
    }
    
    private func mergeIcons(_ iconsWithDisplayProperties: [(image: NSImage, nextSpaceOnDifferentDisplay: Bool, isFullScreen: Bool)]) -> NSImage {
        let numIcons = iconsWithDisplayProperties.count
        let combinedIconWidth = CGFloat(iconsWithDisplayProperties.reduce(0) { (result, icon) in
            result + icon.image.size.width
        })
        let accomodatingGapWidth = CGFloat(numIcons - 1) * gapWidth
        let accomodatingDisplayGapWidth = CGFloat(displayCount - 1) * displayGapWidth
        let totalWidth = combinedIconWidth + accomodatingGapWidth + accomodatingDisplayGapWidth
        let image = NSImage(size: NSSize(width: totalWidth, height: iconSize.height))
        
        image.lockFocus()
        var left = CGFloat.zero
        var right: CGFloat
        var currentSpaceNumber = 1
        var currentFullScreenSpaceNumber = 1
        iconWidths = []
        for icon in iconsWithDisplayProperties {
            icon.image.draw(
                at: NSPoint(x: left, y: 0),
                from: NSRect.zero,
                operation: NSCompositingOperation.sourceOver,
                fraction: 1.0)
            if icon.nextSpaceOnDifferentDisplay {
                right = left + icon.image.size.width + displayGapWidth
            } else {
                right = left + icon.image.size.width + gapWidth
            }
            if !icon.isFullScreen {
                iconWidths.append(IconWidth(left: left + leftMargin, right: right + leftMargin, index: currentSpaceNumber))
                currentSpaceNumber += 1
            } else {
                iconWidths.append(IconWidth(left: left + leftMargin, right: right + leftMargin, index: -currentFullScreenSpaceNumber))
                currentFullScreenSpaceNumber += 1
            }
            left = right
        }
        image.isTemplate = true
        image.unlockFocus()
        
        return image
    }

    private func mergeIconsTwoRows(_ iconsWithDisplayProperties: [(image: NSImage, nextSpaceOnDifferentDisplay: Bool, isFullScreen: Bool)]) -> NSImage {
        // Column describes a stacked pair (top/bottom) and its rendered width and trailing gap
        struct Column { var top: (NSImage, Bool, Int)?; var bottom: (NSImage, Bool, Int)?; var width: CGFloat = 0; var gapAfter: CGFloat = 0 }

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
        case .columnMajor:
            // Original behavior: fill top then bottom per column
            var current = Column()
            var placeTop = true
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                let tag = assignedIndices[idx]
                if placeTop {
                    current.top = (icon.image, icon.isFullScreen, tag)
                    current.width = max(current.width, icon.image.size.width)
                    placeTop = false
                } else {
                    current.bottom = (icon.image, icon.isFullScreen, tag)
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
        case .rowMajor:
            // New behavior: fill entire top row left-to-right, then bottom row
            // First, segment by display to place display gaps correctly
            var segments: [[(image: NSImage, nextDisplay: Bool, isFull: Bool, tag: Int)]] = []
            var cur: [(NSImage, Bool, Bool, Int)] = []
            for (idx, icon) in iconsWithDisplayProperties.enumerated() {
                cur.append((icon.image, icon.nextSpaceOnDifferentDisplay, icon.isFullScreen, assignedIndices[idx]))
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
                        col.top = (t.image, t.isFull, t.tag)
                        col.width = max(col.width, t.image.size.width)
                    }
                    if i < bottom.count {
                        let b = bottom[i]
                        col.bottom = (b.image, b.isFull, b.tag)
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
        let gap = CGFloat(sizes.GAP_HEIGHT_DUALROWS)
        let imageHeight = iconSize.height * 2 + gap
        let image = NSImage(size: NSSize(width: totalWidth, height: imageHeight))

        image.lockFocus()
        var left = CGFloat.zero
        iconWidths = []

        for col in columns {
            if let top = col.top {
                top.0.draw(at: NSPoint(x: left, y: iconSize.height + gap), from: .zero, operation: .sourceOver, fraction: 1.0)
                let right = left + col.width + col.gapAfter
                iconWidths.append(IconWidth(left: left + leftMargin, right: right + leftMargin, top: iconSize.height + gap, bottom: imageHeight, index: top.2))
            }
            if let bottom = col.bottom {
                bottom.0.draw(at: NSPoint(x: left, y: 0), from: .zero, operation: .sourceOver, fraction: 1.0)
                let right = left + col.width + col.gapAfter
                iconWidths.append(IconWidth(left: left + leftMargin, right: right + leftMargin, top: 0, bottom: iconSize.height, index: bottom.2))
            }
            left += col.width + col.gapAfter
        }
        image.isTemplate = true
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
}
