//
//  HUD.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-13.
//  Co-author: Claude Code
//

import Cocoa
import SwiftUI

class HUDPanel {

    private var panel: NSPanel?
    private var dismissTimer: Timer?
    private var hostingView: NSHostingView<HUDView>?

    func show(spaces: [Space], on screen: NSScreen) {
        dismissTimer?.invalidate()

        let hudView = HUDView(spaces: spaces)

        if let hostingView = hostingView, let panel = panel {
            hostingView.rootView = hudView
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
            let size = hostingView.fittingSize
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.maxY - screenFrame.height * 0.8)
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
            panel.alphaValue = 1
            panel.orderFront(nil)
        } else {
            let hosting = NSHostingView(rootView: hudView)
            hosting.invalidateIntrinsicContentSize()
            hosting.layoutSubtreeIfNeeded()
            let size = hosting.fittingSize

            let p = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.nonactivatingPanel],
                backing: .buffered,
                defer: false)
            p.isFloatingPanel = true
            p.level = .floating
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            p.contentView = hosting

            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.maxY - screenFrame.height * 0.8)
            p.setFrameOrigin(origin)
            p.alphaValue = 1
            p.orderFront(nil)

            self.panel = p
            self.hostingView = hosting
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            _ = self
        })
    }

    /// Find the NSScreen corresponding to a display UUID string from CGSCopyManagedDisplaySpaces.
    static func screen(forDisplayID displayID: String) -> NSScreen? {
        let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, displayID as CFString)
        let did = CGDisplayGetDisplayIDFromUUID(uuid)
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               CGDirectDisplayID(num.uint32Value) == did {
                return screen
            }
        }
        return NSScreen.main
    }
}

struct HUDView: View {
    let spaces: [Space]

    @AppStorage("gridColumns") private var gridColumns: Int = 3

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

    private static let cellWidth: CGFloat = 100
    private static let cellHeight: CGFloat = 60
    private static let cellSpacing: CGFloat = 4
    private static let padding: CGFloat = 12

    private var columnCount: Int {
        let maxGroupSize = spacesByDisplay.map(\.count).max() ?? 1
        return max(1, min(gridColumns, maxGroupSize))
    }

    private var gridWidth: CGFloat {
        let cols = CGFloat(columnCount)
        return cols * Self.cellWidth + (cols - 1) * Self.cellSpacing + Self.padding * 2
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(spacesByDisplay.enumerated()), id: \.offset) { groupIdx, group in
                if groupIdx > 0 {
                    Divider().padding(.vertical, 4)
                }
                let cols = Array(
                    repeating: GridItem(.flexible(), spacing: Self.cellSpacing),
                    count: max(1, min(gridColumns, group.count)))
                LazyVGrid(columns: cols, spacing: Self.cellSpacing) {
                    ForEach(Array(group.enumerated()), id: \.element.spaceID) { _, space in
                        SpaceCellView(space: space, showText: false, colorless: true)
                            .frame(height: Self.cellHeight)
                    }
                }
            }
        }
        .padding(Self.padding)
        .background(HUDBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.25).opacity(0.5), lineWidth: 0.5))
        .frame(width: gridWidth)
    }
}

/// NSVisualEffectView with .hudWindow material.
/// Automatically falls back to a solid color when Reduce Transparency is on.
struct HUDBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
