//
//  ColorWellView.swift
//  Spaceman
//

import SwiftUI

struct ColorWellView: NSViewRepresentable {
    @Binding var selectedColor: NSColor?
    var onColorChange: ((NSColor?) -> Void)?

    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell()
        colorWell.isBordered = true
        colorWell.isContinuous = true
        colorWell.color = selectedColor ?? NSColor.systemGray
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorDidChange(_:))
        return colorWell
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        context.coordinator.onColorChange = onColorChange

        // Don't update color if the panel is active - let user interaction control it
        if !nsView.isActive {
            let newColor = selectedColor ?? NSColor.systemGray
            if nsView.color != newColor {
                nsView.color = newColor
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onColorChange: onColorChange)
    }

    class Coordinator: NSObject {
        var onColorChange: ((NSColor?) -> Void)?

        init(onColorChange: ((NSColor?) -> Void)?) {
            self.onColorChange = onColorChange
        }

        @objc func colorDidChange(_ sender: NSColorWell) {
            onColorChange?(sender.color)
        }
    }
}
