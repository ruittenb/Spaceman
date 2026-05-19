//
//  PreferencesWindow.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 2/12/20.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Shared tab state

struct PreferencesTab {
    let id: String
    let title: String
    let icon: String

    static let general = PreferencesTab(
        id: "general",
        title: String(localized: "Tab:General"),
        icon: "gear")
    static let appearance = PreferencesTab(
        id: "appearance",
        title: String(localized: "Tab:Appearance"),
        icon: "paintbrush")
    static let spaces = PreferencesTab(
        id: "spaces",
        title: String(localized: "Tab:Spaces"),
        icon: "square.grid.2x2")
    static let switching = PreferencesTab(
        id: "switching",
        title: String(localized: "Tab:Switching"),
        icon: "arrow.right.arrow.left")
    static let displays = PreferencesTab(
        id: "displays",
        title: String(localized: "Tab:Displays"),
        icon: "display")
    static let about = PreferencesTab(
        id: "about",
        title: String(localized: "Tab:About"),
        icon: "info.circle")

    static let all = [
        general, appearance, spaces, switching, displays,
        about]
}

class PreferencesTabState: ObservableObject {
    @Published var selectedTab = 0
}

// MARK: - Window

class PreferencesWindow: NSWindow, NSToolbarDelegate {
    let tabState = PreferencesTabState()
    private var cancellable: AnyCancellable?

    init() {
        super.init(
            contentRect: NSRect(
                x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.title = String(
            localized: "Spaceman Preferences")
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.moveToActiveSpace]
        setupToolbar()

        cancellable = tabState.$selectedTab
            .removeDuplicates()
            .sink { [weak self] index in
                self?.syncToolbar(to: index)
            }
    }

    // MARK: - Toolbar setup

    private func setupToolbar() {
        let toolbar = NSToolbar(
            identifier: "PreferencesToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier =
            NSToolbarItem.Identifier(PreferencesTab.all[0].id)
        self.toolbar = toolbar
        self.toolbarStyle = .preference
    }

    private func syncToolbar(to index: Int) {
        self.toolbar?.selectedItemIdentifier =
            NSToolbarItem.Identifier(
                PreferencesTab.all[index].id)
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier.flexibleSpace]
        + PreferencesTab.all.map {
            NSToolbarItem.Identifier($0.id)
        }
        + [NSToolbarItem.Identifier.flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        PreferencesTab.all.map {
            NSToolbarItem.Identifier($0.id)
        }
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier
            itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let index = PreferencesTab.all.firstIndex(
            where: { $0.id == itemIdentifier.rawValue })
        else { return nil }

        let tab = PreferencesTab.all[index]
        let item = NSToolbarItem(
            itemIdentifier: itemIdentifier)
        item.label = tab.title
        item.toolTip = "⌘\(index + 1)"
        item.image = NSImage(
            systemSymbolName: tab.icon,
            accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }

    @objc private func toolbarItemClicked(
        _ sender: NSToolbarItem
    ) {
        guard let index = PreferencesTab.all.firstIndex(
            where: { $0.id == sender.itemIdentifier.rawValue })
        else { return }
        tabState.selectedTab = index
    }

    // MARK: - Resize

    /// Resize the window to fit the current content,
    /// pinning the top edge.
    func resizeToFitContent(animate: Bool = true) {
        guard let contentView = contentView else { return }
        let contentSize = contentView.fittingSize
        let newSize = frameRect(
            forContentRect: CGRect(
                origin: .zero, size: contentSize)).size
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
