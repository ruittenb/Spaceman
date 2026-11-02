//
//  SpaceLabelWindow.swift
//  Spaceman
//
//  Floating label window that appears in Mission Control space previews.
//

import Cocoa

class SpaceLabelWindow: NSPanel {
    let label: NSTextField
    let spaceID: String

    init(spaceID: String, name: String) {
        self.spaceID = spaceID
        self.label = NSTextField(labelWithString: name)

        // Calculate size based on text
        let fontSize: CGFloat = 216
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let textSize = (name as NSString).size(withAttributes: [.font: font])
        let padding: CGFloat = 40
        let windowSize = NSSize(
            width: textSize.width + padding,
            height: textSize.height + padding
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Key settings for Mission Control visibility
        collectionBehavior = [.managed, .ignoresCycle]
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false

        // Rounded background
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.5).cgColor
        contentView?.layer?.cornerRadius = 20

        // Label styling
        label.font = font
        label.textColor = .black
        label.alignment = .center
        label.frame = NSRect(origin: .zero, size: frame.size)
        label.autoresizingMask = [.width, .height]
        contentView?.addSubview(label)

        // Center on main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let origin = NSPoint(
                x: screenFrame.midX - frame.width / 2,
                y: screenFrame.midY - frame.height / 2
            )
            setFrameOrigin(origin)
        }
    }

    func updateName(_ name: String) {
        label.stringValue = name

        // Resize window to fit new text
        let textSize = (name as NSString).size(withAttributes: [.font: label.font!])
        let padding: CGFloat = 40
        let newSize = NSSize(
            width: textSize.width + padding,
            height: textSize.height + padding
        )
        setContentSize(newSize)
        label.frame = NSRect(origin: .zero, size: newSize)
    }

    func bindToSpace() {
        guard let spaceInt = Int(spaceID), windowNumber > 0 else { return }
        let cid = _CGSDefaultConnection()
        let winArray = [NSNumber(value: windowNumber)] as CFArray
        let spaceArray = [NSNumber(value: spaceInt)] as CFArray

        // Get current spaces and remove from all except target
        if let spacesRef = CGSCopySpacesForWindows(cid, 7, winArray),
           let currentSpaces = spacesRef.takeRetainedValue() as? [NSNumber] {
            let toRemove = currentSpaces.filter { $0.intValue != spaceInt }
            if !toRemove.isEmpty {
                CGSRemoveWindowsFromSpaces(cid, winArray, toRemove as CFArray)
            }
        }
        CGSAddWindowsToSpaces(cid, winArray, spaceArray)
    }
}
