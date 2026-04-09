//
//  PreferencesWindow.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 2/12/20.
//

import SwiftUI
import AppKit

class PreferencesWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.title = "Spaceman Preferences"
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.moveToActiveSpace]
    }

    /// Resize the window to fit the current content, pinning the top edge.
    func resizeToFitContent(animate: Bool = true) {
        guard let contentView = contentView else { return }
        let contentSize = contentView.fittingSize
        let newSize = frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
        var frame = frame
        frame.origin.y += frame.height - newSize.height
        frame.size = newSize
        if animate {
            animator().setFrame(frame, display: false)
        } else {
            setFrame(frame, display: false)
        }
    }
}
