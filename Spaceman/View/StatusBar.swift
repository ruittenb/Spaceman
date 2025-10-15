//
//  StatusBar.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Foundation
import Sparkle
import SwiftUI

class StatusBar: NSObject, NSMenuDelegate, SPUUpdaterDelegate {
    @AppStorage("hideInactiveSpaces") private var hideInactiveSpaces = false
    @AppStorage("visibleSpacesMode") private var visibleSpacesModeRaw: Int = VisibleSpacesMode.all.rawValue
    @AppStorage("schema") private var keySet = KeySet.toprow

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }
    private var statusBarItem: NSStatusItem!
    private var statusBarMenu: NSMenu!
    private var updatesItem: NSMenuItem!
    private var prefItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    private var prefsWindow: PreferencesWindow!
    private var spaceSwitcher: SpaceSwitcher!
    private var shortcutHelper: ShortcutHelper!
    private var updaterController: SPUStandardUpdaterController!
    private var aboutView: NSHostingView<AboutView>!

    public var iconCreator: IconCreator!

    override init() {
        super.init()

        shortcutHelper = ShortcutHelper()
        spaceSwitcher = SpaceSwitcher()
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarMenu = NSMenu()
        statusBarMenu.autoenablesItems = false
        statusBarMenu.delegate = self

        prefsWindow = PreferencesWindow()

        let about = NSMenuItem()
        let aboutViewContent = AboutView()
        aboutView = NSHostingView(rootView: aboutViewContent)
        aboutView.frame = NSRect(x: 0, y: 0, width: 220, height: 70)
        about.view = aboutView

        updatesItem = NSMenuItem(
            title: "Check for updates...",
            action: #selector(updaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        updatesItem.target = updaterController

        // Set up update badge - start with no badge, show only when update available
        if #available(macOS 14.0, *) {
            updatesItem.badge = nil
        }

        prefItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferencesWindow(_:)),
            keyEquivalent: "")
        prefItem.target = self
        Task { @MainActor in
            prefItem.setShortcut(for: .preferences)
        }

        quitItem = NSMenuItem(
            title: "Quit Spaceman",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "")

        statusBarMenu.addItem(about)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(updatesItem)
        statusBarMenu.addItem(prefItem)
        statusBarMenu.addItem(quitItem)
        //statusBarItem.menu = statusBarMenu

        statusBarItem.button?.action = #selector(handleClick)
        statusBarItem.button?.target = self
        statusBarItem.button?.sendAction(on: [.rightMouseDown, .leftMouseDown])
    }

    @objc func handleClick(_ sbButton: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if event.type == .rightMouseDown {
                // Show the menu on right-click
                if let sbMenu = self.statusBarMenu {
                    let buttonFrame = sbButton.window?.convertToScreen(sbButton.frame) ?? .zero
                    // This calculation is not right, but looks good. This is likely because of the
                    // NSMenu popup having its own visual padding, borders and/or drop shadows.
                    let menuOrigin = CGPoint(x: buttonFrame.minX, y: buttonFrame.minY - CGFloat(self.iconCreator.sizes.ICON_HEIGHT) / 2)
                    sbMenu.minimumWidth = buttonFrame.width
                    sbMenu.popUp(positioning: nil, at: menuOrigin, in: nil)
                    sbButton.isHighlighted = false
                }
            } else if (event.type == .leftMouseDown) {
                // Switch desktops on left click, unless one single space shown
                let mode: VisibleSpacesMode = {
                    if UserDefaults.standard.object(forKey: "visibleSpacesMode") == nil && self.hideInactiveSpaces {
                        return .currentOnly
                    }
                    return self.visibleSpacesMode
                }()
                guard mode != .currentOnly else {
                    print("Not switching: just one space visible")
                    return
                }
                let locationInButton = sbButton.convert(event.locationInWindow, from: nil)
                // Convert to bottom-origin coordinates for hit testing
                let adjPoint = NSPoint(x: locationInButton.x, y: sbButton.bounds.height - locationInButton.y)
                self.spaceSwitcher.switchUsingLocation(
                    iconWidths: self.iconCreator.iconWidths,
                    point: adjPoint,
                    onError: self.flashStatusBar)
            } else {
                print("Other event: \(event.type)")
            }
        }
    }

    func flashStatusBar() {
        if let button = statusBarItem.button {
            let blinkInterval: TimeInterval = 0.1
            button.isHighlighted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + blinkInterval) {
                button.isHighlighted = false
                DispatchQueue.main.asyncAfter(deadline: .now() + blinkInterval) {
                    button.isHighlighted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + blinkInterval) {
                        button.isHighlighted = false
                    }
                }
            }
        }
    }

    func getButtonFrame() -> NSRect? {
        return statusBarItem.button?.frame
    }

    func updateStatusBar(withIcon icon: NSImage, withSpaces spaces: [Space]) {
        // update icon
        if let statusBarButton = statusBarItem.button {
            statusBarButton.image = icon
        }
        // update menu
        guard spaces.count > 0 else {
            return
        }
        // Remove previously inserted dynamic items between the fixed header and the updates item
        let updatesIdx = statusBarMenu.index(of: updatesItem)
        if updatesIdx > 2 {
            for _ in 2..<updatesIdx { statusBarMenu.removeItem(at: 2) }
        } else {
            // Fallback to old behavior if updatesItem not found
            while statusBarMenu.items.count > 2 && !statusBarMenu.items[2].isSeparatorItem {
                statusBarMenu.removeItem(at: 2)
            }
        }
        // Build items grouped by display with a separator between displays
        var itemsToInsert: [NSMenuItem] = []
        var lastDisplayID: String? = nil
        for space in spaces {
            if let last = lastDisplayID, last != space.displayID {
                itemsToInsert.append(NSMenuItem.separator())
            }
            itemsToInsert.append(makeSwitchToSpaceItem(space: space))
            lastDisplayID = space.displayID
        }
        // Ensure there is a separator between the last space item and the updates item
        if !itemsToInsert.isEmpty {
            itemsToInsert.append(NSMenuItem.separator())
        }
        // Insert in order at index 2
        var insertIndex = 2
        for item in itemsToInsert { statusBarMenu.insertItem(item, at: insertIndex); insertIndex += 1 }
    }

    @objc func showPreferencesWindow(_ sender: AnyObject) {
        let hostedPrefsView = NSHostingView(rootView: PreferencesView(parentWindow: prefsWindow))
        prefsWindow.contentView = hostedPrefsView

        prefsWindow.center()
        prefsWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func makeSwitchToSpaceItem(space: Space) -> NSMenuItem {
        let globalSpaceNumber = space.spaceNumber
        let spaceName = space.spaceName

        let mask = shortcutHelper.getModifiersAsFlags()
        var shortcutKey = ""
        if space.spaceByDesktopID == "F1" {
            // F1 fullscreen maps to space 11 -> shortcut "-"
            shortcutKey = "-"
        } else if space.spaceByDesktopID == "F2" {
            // F2 fullscreen maps to space 12 -> shortcut "=" or "+"
            shortcutKey = (keySet == KeySet.numpad ? "+" : "=")
        } else if globalSpaceNumber >= 1 && globalSpaceNumber <= 9 {
            shortcutKey = String(globalSpaceNumber)
        } else if globalSpaceNumber == 10 {
            shortcutKey = "0"
        }
        // For spaces > 12: no shortcut (macOS limitation)

        let icon = NSImage(imageLiteralResourceName: "SpaceIconNumNormalActive")
        let menuIcon = iconCreator.createRectWithNumberIcon(
            icons: [icon],
            index: 0,
            space: space,
            fraction: 0.6)
        let item = NSMenuItem(
            title: spaceName,
            action: #selector(switchToSpace(_:)),
            keyEquivalent: shortcutKey)
        item.keyEquivalentModifierMask = mask
        item.target = self
        switch space.spaceByDesktopID {
        case "F1":
            item.tag = -1
        case "F2":
            item.tag = -2
        default:
            item.tag = globalSpaceNumber
        }
        item.image = menuIcon
        if space.isCurrentSpace || shortcutKey == "" {
            item.isEnabled = false
            if space.isCurrentSpace {
                item.state = .on // tick mark
            }
        }
        return item
    }

    @objc func switchToSpace(_ sender: NSMenuItem) {
        let spaceNumber = sender.tag
        guard (spaceNumber >= -2 && spaceNumber != 0 && spaceNumber <= 10) else {
            return
        }
        spaceSwitcher.switchToSpace(spaceNumber: spaceNumber, onError: flashStatusBar)
    }

    // MARK: - SPUUpdaterDelegate
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // Update is available - show badge with version number
        DispatchQueue.main.async {
            if #available(macOS 14.0, *) {
                let versionString = item.displayVersionString
                self.updatesItem.badge = NSMenuItemBadge(string: "v\(versionString) available")
            }
        }
    }

    func hideBadge() {
        // Hide the 'available' badge in the menu
        DispatchQueue.main.async {
            if #available(macOS 14.0, *) {
                self.updatesItem.badge = nil
            }
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        // No update available
        hideBadge()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        // Error occurred
        hideBadge()
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        // About to install
        hideBadge()
    }
}
