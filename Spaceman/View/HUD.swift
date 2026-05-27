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

    /// Determine the display ID where a space switch occurred.
    /// Compares previous and current spaces to find which display's active space changed.
    /// Returns nil if the HUD should not appear (wrong trigger, fullscreen, no change detected).
    static func targetDisplayID(
        spaces: [Space], previousSpaces: [Space],
        trigger: SpaceUpdateTrigger, showHUD: Bool
    ) -> String? {
        guard showHUD && trigger == .spaceSwitch else { return nil }

        // Build a map of displayID → current spaceID for old and new state
        let oldCurrent = Dictionary(
            previousSpaces.filter(\.isCurrentSpace).map { ($0.displayID, $0.spaceID) },
            uniquingKeysWith: { first, _ in first })
        let newCurrent = Dictionary(
            spaces.filter(\.isCurrentSpace).map { ($0.displayID, $0.spaceID) },
            uniquingKeysWith: { first, _ in first })

        // Find the display where the active space changed
        for (displayID, newSpaceID) in newCurrent where oldCurrent[displayID] != newSpaceID {
            // Skip if the new current space on this display is fullscreen
            let isFull = spaces.first { $0.spaceID == newSpaceID }?.isFullScreen ?? false
            if !isFull { return displayID }
        }
        return nil
    }

    /// Group spaces by display, preserving order.
    static func spacesByDisplay(_ spaces: [Space]) -> [[Space]] {
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
    @AppStorage("hudAlwaysTransparent") private var hudAlwaysTransparent = false

    private var spacesByDisplay: [[Space]] {
        HUDPanel.spacesByDisplay(spaces)
    }

    private static let cellWidth: CGFloat = 100
    private static let cellHeight: CGFloat = 60
    private static let cellSpacing: CGFloat = 4
    private static let padding: CGFloat = 12

    private var columnCount: Int {
        max(1, gridColumns)
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
                    count: max(1, gridColumns))
                LazyVGrid(columns: cols, spacing: Self.cellSpacing) {
                    ForEach(Array(group.enumerated()), id: \.element.spaceID) { _, space in
                        SpaceCellView(space: space, showText: false, colorless: true)
                            .frame(height: Self.cellHeight)
                    }
                }
            }
        }
        .padding(Self.padding)
        .background(HUDBackground(forceTransparent: hudAlwaysTransparent))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.25).opacity(0.5), lineWidth: 0.5))
        .frame(width: gridWidth)
    }
}

/// NSVisualEffectView with .hudWindow material.
/// Automatically falls back to a solid color when Reduce Transparency is on,
/// unless `forceTransparent` is true — then the view's alpha is reduced
/// so the opaque fallback becomes see-through.
struct HUDBackground: NSViewRepresentable {
    var forceTransparent: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        applyAlpha(to: view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        applyAlpha(to: nsView)
    }

    private func applyAlpha(to view: NSVisualEffectView) {
        let shouldReduce = NSWorkspace.shared
            .accessibilityDisplayShouldReduceTransparency
        view.alphaValue = (forceTransparent && shouldReduce) ? 0.7 : 1.0
    }
}
