//
//  SpaceGridPopover.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-03.
//  Co-author: Claude Code
//

import SwiftUI

struct SpaceGridPopover: View {
    let spaces: [Space]
    var onSwitch: (Int) -> Void

    @AppStorage("gridColumns") private var gridColumns: Int = 3

    var body: some View {
        VStack(spacing: 8) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4),
                                count: max(1, min(gridColumns, spaces.count)))
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(spaces.enumerated()), id: \.element.spaceID) { _, space in
                    SpaceCellView(space: space)
                        .onTapGesture {
                            if !space.isCurrentSpace {
                                let index = Int(space.spaceByDesktopID) ?? Space.unswitchableIndex
                                onSwitch(index)
                            }
                        }
                }
            }

            Divider()

            HStack {
                Text("Columns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(gridColumns) },
                    set: { gridColumns = max(1, Int($0)) }
                ), in: 1...Double(max(2, spaces.count)), step: 1)
                Text("\(gridColumns)")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 16, alignment: .trailing)
            }
        }
        .padding(12)
        .frame(minWidth: 160)
    }
}

struct SpaceGridMenuView: View {
    let spaces: [Space]
    var onSwitch: (Int) -> Void
    let switchMap: [String: Int]
    var menuWidth: CGFloat

    @AppStorage("gridColumns") private var gridColumns: Int = 3

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4),
                            count: max(1, min(gridColumns, spaces.count)))
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(spaces.enumerated()), id: \.element.spaceID) { _, space in
                let switchIndex = switchMap[space.spaceID]
                let desktopNum = if let idx = switchIndex, idx > 0 { idx } else { nil as Int? }
                SpaceCellView(space: space)
                    .onTapGesture {
                        if let num = desktopNum, !space.isCurrentSpace {
                            onSwitch(num)
                        }
                    }
            }
        }
        .padding(8)
        .frame(width: menuWidth)
    }
}

struct SpaceCellView: View {
    let space: Space

    private var hasName: Bool {
        !space.spaceName.isEmpty
    }

    private var cellColor: Color {
        if let hex = space.colorHex, let nsColor = NSColor.fromHex(hex) {
            return Color(nsColor)
        }
        return Color.gray.opacity(0.3)
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(space.spaceByDesktopID)
                .font(.system(size: hasName ? 9 : 11,
                              weight: space.isCurrentSpace ? .bold : .regular))
            if hasName {
                Text(space.spaceName)
                    .font(.system(size: 11, weight: space.isCurrentSpace ? .bold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(cellColor.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, lineWidth: space.isCurrentSpace ? 2.5 : 0)
        )
        .foregroundColor(.primary)
    }
}
