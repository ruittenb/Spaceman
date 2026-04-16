//
//  QuickRenameView.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-16.
//  Co-author: Claude Code
//

import SwiftUI

struct QuickRenameView: View {
    @State private var name: String
    @State private var color: NSColor?
    @FocusState private var isFocused: Bool
    var onRename: (String) -> Void
    var onColorChange: (NSColor?) -> Void
    var onCancel: () -> Void

    init(currentName: String, currentColorHex: String?,
         onRename: @escaping (String) -> Void,
         onColorChange: @escaping (NSColor?) -> Void,
         onCancel: @escaping () -> Void) {
        _name = State(initialValue: currentName)
        _color = State(initialValue: currentColorHex.flatMap { NSColor.fromHex($0) })
        self.onRename = onRename
        self.onColorChange = onColorChange
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 32, height: 32)
                TextField(String(localized: "Space name"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { onRename(name) }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                ColorWellView(
                    selectedColor: $color,
                    onColorChange: { newColor in
                        color = newColor
                        onColorChange(newColor)
                    }
                )
                .frame(width: 35, height: 24)
                if color != nil {
                    Button {
                        color = nil
                        onColorChange(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button(String(localized: "Cancel")) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "Rename")) { onRename(name) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
