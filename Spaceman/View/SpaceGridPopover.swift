//
//  SpaceGridPopover.swift
//  Spaceman
//
//  Created by Claude Code on 03/04/2026.
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

private struct SpaceCellView: View {
    let space: Space

    private var label: String {
        space.spaceName.isEmpty ? space.spaceByDesktopID : space.spaceName
    }

    private var cellColor: Color {
        if let hex = space.colorHex, let nsColor = NSColor.fromHex(hex) {
            return Color(nsColor)
        }
        return space.isCurrentSpace ? Color.accentColor : Color.gray.opacity(0.3)
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: space.isCurrentSpace ? .bold : .regular))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor.opacity(space.isCurrentSpace ? 1.0 : 0.6))
            )
            .foregroundColor(space.isCurrentSpace ? .white : .primary)
    }
}
