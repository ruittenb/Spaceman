//
//  SpaceGrid.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-03.
//  Co-author: Claude Code
//

import SwiftUI

struct SpaceGridMenuView: View {
    let spaces: [Space]
    var onSwitch: (Int) -> Void
    let switchMap: [String: Int]
    var enabledSwitchMap: [String: Int]
    var hasArrowShortcuts: Bool = true
    var menuWidth: CGFloat

    @AppStorage("gridColumns") private var gridColumns: Int = 3
    @AppStorage("switchingMode") private var switchingMode = SwitchingMode.smooth.rawValue

    /// Spaces grouped by display, preserving order.
    private var spacesByDisplay: [[Space]] {
        var groups: [[Space]] = []
        var currentGroup: [Space] = []
        var lastDisplayID: String?
        for space in spaces {
            if let last = lastDisplayID, last != space.displayID {
                groups.append(currentGroup)
                currentGroup = []
            }
            currentGroup.append(space)
            lastDisplayID = space.displayID
        }
        if !currentGroup.isEmpty { groups.append(currentGroup) }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(spacesByDisplay.enumerated()), id: \.offset) { groupIdx, group in
                if groupIdx > 0 {
                    Divider().padding(.vertical, 2)
                }
                let colCount = max(1, min(gridColumns, group.count))
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4),
                                    count: colCount)
                let cellHeight: CGFloat = 50
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(group.enumerated()), id: \.element.spaceID) { _, space in
                        let enabledTag = enabledSwitchMap[space.spaceID]
                        let enabled = Space.canSwitch(
                            space: space, switchTag: enabledTag,
                            switchingMode: SwitchingMode(rawValue: switchingMode) ?? .smooth,
                            spaces: spaces,
                            enabledSwitchMap: enabledSwitchMap,
                            hasArrowShortcuts: hasArrowShortcuts)
                        SpaceCellView(space: space, enabled: enabled)
                            .frame(height: cellHeight)
                            .onTapGesture {
                                guard enabled else { return }
                                onSwitch(Space.switchTag(
                                    switchMapEntry: switchMap[space.spaceID],
                                    spaceNumber: space.spaceNumber))
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: menuWidth)
    }
}

struct SpaceCellView: View {
    let space: Space
    var enabled: Bool = true
    var showText: Bool = true
    var colorless: Bool = false

    private var hasName: Bool {
        !space.spaceName.isEmpty
    }

    private var cellNSColor: NSColor? {
        if let hex = space.colorHex, let nsColor = NSColor.fromHex(hex) {
            return nsColor
        }
        return nil
    }

    private var cellColor: Color {
        if let nsColor = cellNSColor {
            return Color(nsColor)
        }
        return Color.gray.opacity(0.3)
    }

    private var cellAlpha: CGFloat {
        space.isCurrentSpace ? 1.0 : Constants.inactiveAlpha
    }

    private var colorlessCellColor: Color {
        if colorless {
            return space.isCurrentSpace ? Color.accentColor : Color(white: 0.25).opacity(0.5)
        }
        return cellColor.opacity(cellAlpha)
    }

    private var textColor: Color {
        guard let nsColor = cellNSColor else { return .primary }
        return Color(nsColor.contrastingTextColor(withAlpha: cellAlpha, over: .windowBackgroundColor))
    }

    var body: some View {
        VStack(spacing: 1) {
            if showText {
                Text(space.spaceLabel)
                    .font(.system(size: 9,
                                  weight: space.isCurrentSpace ? .bold : .regular))
                Text(hasName ? space.spaceName : "\u{00A0}")
                    .font(.system(size: 11, weight: space.isCurrentSpace ? .bold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(colorlessCellColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(colorless ? .clear : Color.accentColor,
                        lineWidth: space.isCurrentSpace ? 2.5 : 0)
        )
        .foregroundColor(textColor)
    }
}
