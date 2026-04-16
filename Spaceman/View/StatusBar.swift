//
//  StatusBar.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Foundation
import Sparkle
import SwiftUI

class StatusBar: NSObject, NSMenuDelegate, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    @AppStorage("visibleSpacesMode") private var visibleSpacesModeRaw: Int = VisibleSpacesMode.all.rawValue
    @AppStorage("displayStyle") private var displayStyle = IconText.numbers
    @AppStorage("iconSize") private var iconSize = IconSize.medium
    @AppStorage("rowLayout") private var rowLayout = RowLayout.singleRow
    @AppStorage("decorationActive") private var decorationActive = IconStyle.filledRounded
    @AppStorage("decorationInactive") private var decorationInactive = IconStyle.borderedRounded
    @AppStorage("lastActiveShape") private var lastActiveShapeRaw: Int = IconShape.rounded.rawValue
    @AppStorage("lastActiveFill") private var lastActiveFillRaw: Int = IconFill.filled.rawValue
    @AppStorage("lastInactiveShape") private var lastInactiveShapeRaw: Int = IconShape.rounded.rawValue
    @AppStorage("lastInactiveFill") private var lastInactiveFillRaw: Int = IconFill.bordered.rawValue
    @AppStorage("showFullscreenSpaces") private var showFullscreenSpaces = true
    @AppStorage("useVariableWidth") private var useVariableWidth = false
    @AppStorage("fontDesign") private var fontDesign = FontDesign.monospaced
    @AppStorage("showMissionControl") private var showMissionControl = false
    @AppStorage("showNavArrows") private var showNavArrows = false
    @AppStorage("navigateAnywhere") private var navigateAnywhere = false
    @AppStorage("spaceDisplayMode") private var spaceDisplayMode = SpaceDisplayMode.list

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }
    private var statusBarItem: NSStatusItem!
    private var statusBarMenu: NSMenu!
    private var updatesItem: NSMenuItem!
    private var refreshItem: NSMenuItem!
    private var quickRenameItem: NSMenuItem!
    private var prefItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    private var rowLayoutMenuItem: NSMenuItem!
    private var layoutMenuItem: NSMenuItem!
    private var iconStyleMenuItem: NSMenuItem!
    private var iconShapeMenuItem: NSMenuItem!
    private var spacesShownMenuItem: NSMenuItem!
    private var prefsWindow: PreferencesWindow!
    private var tabChangeObserver: NSObjectProtocol?
    private var scrollAccumulator: CGFloat = 0
    private var lastScrollTime: Date = .distantPast
    private var spaceSwitcher: SpaceSwitcher!
    private var shortcutHelper: ShortcutHelper!
    private var currentSpaces: [Space] = []
    private var updaterController: SPUStandardUpdaterController!
    private var aboutView: NSHostingView<AboutView>!
    private var missingShortcutBalloon: NSPopover?
    private var quickRenamePanel: NSPanel?

    public var iconCreator: IconCreator!

    override init() {
        super.init()

        shortcutHelper = ShortcutHelper()
        spaceSwitcher = SpaceSwitcher()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)

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
            title: String(localized: "Check for updates…"),
            action: #selector(updaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        updatesItem.target = updaterController
        updatesItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)

        // Set up update badge - start with no badge, show only when update available
        if #available(macOS 14.0, *) {
            updatesItem.badge = nil
        }

        refreshItem = NSMenuItem(
            title: String(localized: "Refresh"),
            action: #selector(refreshSpaces(_:)),
            keyEquivalent: "")
        refreshItem.target = self
        Task { @MainActor in
            refreshItem.setShortcut(for: .refresh)
        }

        quickRenameItem = NSMenuItem(
            title: String(localized: "Rename Current Space…"),
            action: #selector(quickRenameCurrentSpace(_:)),
            keyEquivalent: "")
        quickRenameItem.target = self
        Task { @MainActor in
            quickRenameItem.setShortcut(for: .quickRename)
        }

        prefItem = NSMenuItem(
            title: String(localized: "Preferences…"),
            action: #selector(showPreferencesWindow(_:)),
            keyEquivalent: "")
        prefItem.target = self
        Task { @MainActor in
            prefItem.setShortcut(for: .preferences)
        }

        quitItem = NSMenuItem(
            title: String(localized: "Quit Spaceman"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "")
        quitItem.image = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: nil)

        // Build settings submenus
        let rowLayoutSubmenu = NSMenu()
        for layout in RowLayout.allCases {
            let item = NSMenuItem(title: layout.menuLabel, action: #selector(selectRowLayout(_:)), keyEquivalent: "")
            item.tag = layout.rawValue
            item.target = self
            rowLayoutSubmenu.addItem(item)
        }
        rowLayoutMenuItem = NSMenuItem(title: String(localized: "Row Layout"), action: nil, keyEquivalent: "")
        rowLayoutMenuItem.submenu = rowLayoutSubmenu

        // Icon size submenu is rebuilt dynamically in menuWillOpen
        layoutMenuItem = NSMenuItem(title: String(localized: "Icon Size"), action: nil, keyEquivalent: "")
        layoutMenuItem.submenu = NSMenu()

        let iconStyleSubmenu = NSMenu()
        for style in IconText.allCases {
            let item = NSMenuItem(title: style.menuLabel, action: #selector(selectIconStyle(_:)), keyEquivalent: "")
            item.tag = style.rawValue
            item.target = self
            iconStyleSubmenu.addItem(item)
        }
        iconStyleSubmenu.addItem(NSMenuItem.separator())
        for design in FontDesign.allCases {
            let item = NSMenuItem(title: design.menuLabel, action: #selector(selectFont(_:)), keyEquivalent: "")
            item.tag = design.rawValue
            item.target = self
            iconStyleSubmenu.addItem(item)
        }
        iconStyleMenuItem = NSMenuItem(title: String(localized: "Icon Text"), action: nil, keyEquivalent: "")
        iconStyleMenuItem.submenu = iconStyleSubmenu

        let iconShapeSubmenu = NSMenu()
        let noDecoItem = NSMenuItem(
            title: IconShape.noDecoration.menuLabel,
            action: #selector(selectIconShape(_:)), keyEquivalent: "")
        noDecoItem.tag = IconShape.noDecoration.rawValue
        noDecoItem.target = self
        iconShapeSubmenu.addItem(noDecoItem)
        iconShapeSubmenu.addItem(NSMenuItem.separator())
        for shape in IconShape.allCases where shape != .noDecoration {
            let item = NSMenuItem(title: shape.menuLabel, action: #selector(selectIconShape(_:)), keyEquivalent: "")
            item.tag = shape.rawValue
            item.target = self
            iconShapeSubmenu.addItem(item)
        }
        iconShapeSubmenu.addItem(NSMenuItem.separator())
        for fill in IconFill.allCases {
            let item = NSMenuItem(title: fill.menuLabel, action: #selector(selectIconFill(_:)), keyEquivalent: "")
            item.tag = fill.rawValue
            item.target = self
            iconShapeSubmenu.addItem(item)
        }
        iconShapeMenuItem = NSMenuItem(title: String(localized: "Icon Style"), action: nil, keyEquivalent: "")
        iconShapeMenuItem.submenu = iconShapeSubmenu

        let spacesShownSubmenu = NSMenu()
        for mode in VisibleSpacesMode.allCases {
            let item = NSMenuItem(title: mode.menuLabel, action: #selector(selectSpacesShown(_:)), keyEquivalent: "")
            item.tag = mode.rawValue
            item.target = self
            spacesShownSubmenu.addItem(item)
        }
        spacesShownSubmenu.addItem(NSMenuItem.separator())
        let showFullscreenItem = NSMenuItem(
            title: String(localized: "Fullscreen Spaces"),
            action: #selector(toggleShowFullscreenSpaces), keyEquivalent: ""
        )
        showFullscreenItem.target = self
        spacesShownSubmenu.addItem(showFullscreenItem)
        spacesShownSubmenu.addItem(NSMenuItem.separator())
        let showMCItem = NSMenuItem(
            title: String(localized: "Mission Control Button"),
            action: #selector(toggleShowMissionControl), keyEquivalent: ""
        )
        showMCItem.target = self
        spacesShownSubmenu.addItem(showMCItem)
        let showArrowsItem = NSMenuItem(
            title: String(localized: "Navigation Arrows"),
            action: #selector(toggleShowNavArrows), keyEquivalent: ""
        )
        showArrowsItem.target = self
        spacesShownSubmenu.addItem(showArrowsItem)

        spacesShownMenuItem = NSMenuItem(title: String(localized: "Buttons Shown"), action: nil, keyEquivalent: "")
        spacesShownMenuItem.submenu = spacesShownSubmenu

        statusBarMenu.addItem(about)
        statusBarMenu.addItem(NSMenuItem.separator())
        // Dynamic space items will be inserted starting at index 2
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(layoutMenuItem)
        statusBarMenu.addItem(iconStyleMenuItem)
        statusBarMenu.addItem(iconShapeMenuItem)
        statusBarMenu.addItem(rowLayoutMenuItem)
        statusBarMenu.addItem(spacesShownMenuItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(quickRenameItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(refreshItem)
        statusBarMenu.addItem(prefItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(updatesItem)
        statusBarMenu.addItem(quitItem)
        // statusBarItem.menu = statusBarMenu

        statusBarItem.button?.action = #selector(handleClick)
        statusBarItem.button?.target = self
        statusBarItem.button?.sendAction(on: [.rightMouseDown, .leftMouseDown])

        // Scroll wheel on the status bar icon changes the layout size
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self,
                  let buttonWindow = self.statusBarItem.button?.window,
                  event.window === buttonWindow else { return event }
            self.handleScroll(event)
            return nil // consume the event
        }

        // Tracking area for tooltips on hover
        if let button = statusBarItem.button {
            let area = NSTrackingArea(
                rect: button.bounds,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            )
            button.addTrackingArea(area)
        }
    }

    @objc func handleClick(_ sbButton: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }
        // Capture the mouse position here, instead of using event.locationInWindow,
        // which may be invalid for clicks in the 1-2px gap above/below the button.
        // Also capture the button frame now, before the asyncAfter delay, so that
        // it is from the same moment as the mouse location.
        let mouseLocation = NSEvent.mouseLocation
        let buttonFrame = sbButton.window?.convertToScreen(sbButton.frame) ?? .zero
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if event.type == .rightMouseDown {
                if let sbMenu = self.statusBarMenu {
                    let useGrid = self.spaceDisplayMode == .grid
                    if useGrid {
                        self.replaceDynamicItemsWithGrid()
                    }
                    let menuOrigin = CGPoint(
                        x: buttonFrame.minX,
                        y: buttonFrame.minY - CGFloat(self.iconCreator.sizes.FONT_SIZE) / 2)
                    sbMenu.minimumWidth = Constants.minMenuWidth
                    sbMenu.popUp(positioning: nil, at: menuOrigin, in: nil)
                    sbButton.isHighlighted = false
                    if useGrid {
                        self.restoreDynamicItemsAsList()
                    }
                }
            } else if event.type == .leftMouseDown {
                // Switch desktops on left click, unless one single space shown
                guard self.visibleSpacesMode != .currentOnly else {
                    print("Not switching: just one space visible")
                    return
                }
                // Use screen coordinates for hit testing; sbButton.convert() returns
                // garbage when the click lands in the 1-2px gap above/below the button
                let locationInButton = NSPoint(
                    x: mouseLocation.x - buttonFrame.minX,
                    y: mouseLocation.y - buttonFrame.minY)
                // Convert to image-relative coordinates for hit testing
                let adjPoint = NSPoint(
                    x: locationInButton.x - self.imageHorizontalMargin(of: sbButton),
                    y: locationInButton.y)
                self.spaceSwitcher.switchUsingLocation(
                    iconWidths: self.iconCreator.iconWidths,
                    point: adjPoint,
                    spaces: self.currentSpaces,
                    navigateAnywhere: self.navigateAnywhere,
                    onError: self.flashStatusBar,
                    onMissingShortcut: { [weak self] kind in
                        self?.showMissingShortcutBalloon(kind: kind)
                    })
            } else {
                print("Other event: \(event.type)")
            }
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard event.modifierFlags.contains(.option) else { return }
        let now = Date()
        if now.timeIntervalSince(lastScrollTime) > 0.3 {
            scrollAccumulator = 0
        }
        lastScrollTime = now
        scrollAccumulator += event.scrollingDeltaY
        let threshold: CGFloat = 8

        if scrollAccumulator > threshold {
            scrollAccumulator = 0
            var next = iconSize.larger
            while let candidate = next, rowLayout.isTwoRows && Constants.sizesTwoRows[candidate] == nil {
                next = candidate.larger
            }
            if let next = next {
                iconSize = next
                postRefreshNotification()
            }
        } else if scrollAccumulator < -threshold {
            scrollAccumulator = 0
            var next = iconSize.smaller
            while let candidate = next, rowLayout.isTwoRows && Constants.sizesTwoRows[candidate] == nil {
                next = candidate.smaller
            }
            if let next = next {
                iconSize = next
                postRefreshNotification()
            }
        }
    }

    func flashStatusBar() {
        if let button = statusBarItem.button {
            let blinkInterval: TimeInterval = 0.1
            let dimAlpha: CGFloat = 0.3
            button.alphaValue = dimAlpha
            DispatchQueue.main.asyncAfter(deadline: .now() + blinkInterval) {
                button.alphaValue = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + blinkInterval) {
                    button.alphaValue = dimAlpha
                    DispatchQueue.main.asyncAfter(deadline: .now() + blinkInterval) {
                        button.alphaValue = 1.0
                    }
                }
            }
        }
    }

    // MARK: - Missing Shortcut Balloon

    private func showMissingShortcutBalloon(kind: MissingShortcutKind) {
        dismissMissingShortcutBalloon()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let viewController = NSViewController()
        let hostingView = NSHostingView(rootView: MissingShortcutBalloonView(
            kind: kind,
            onConfigure: { [weak self] in
                self?.dismissMissingShortcutBalloon()
                openMissionControlShortcuts()
            }
        ))
        hostingView.frame.size = hostingView.intrinsicContentSize
        viewController.view = hostingView
        popover.contentViewController = viewController

        if let button = statusBarItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        missingShortcutBalloon = popover
    }

    private func dismissMissingShortcutBalloon() {
        missingShortcutBalloon?.close()
        missingShortcutBalloon = nil
    }

    // MARK: - Tooltips

    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        // Required by NSTrackingArea with .mouseEnteredAndExited; no action needed
    }

    @objc(mouseMoved:) func mouseMoved(with event: NSEvent) {
        guard let button = statusBarItem.button else { return }
        let locationInButton = button.convert(event.locationInWindow, from: nil)
        let x = locationInButton.x - imageHorizontalMargin(of: button)

        let imageHeight = button.image?.size.height ?? button.bounds.height
        let y = imageHeight - (locationInButton.y - imageVerticalMargin(of: button))
        var tooltip: String?
        for iconWidth in iconCreator.iconWidths {
            let hitX = x >= iconWidth.left && x < iconWidth.right
            let hasY = iconWidth.top != 0 || iconWidth.bottom != 0
            let hitY = hasY ? (y >= iconWidth.top && y < iconWidth.bottom) : true
            if hitX && hitY {
                switch iconWidth.index {
                case Space.previousSpaceIndex:     tooltip = String(localized: "Previous")
                case Space.missionControlIndex:    tooltip = String(localized: "Mission Control")
                case Space.nextSpaceIndex:         tooltip = String(localized: "Next")
                default: break
                }
                break
            }
        }
        button.toolTip = tooltip
    }

    @objc(mouseExited:) func mouseExited(with event: NSEvent) {
        statusBarItem.button?.toolTip = nil
    }

    /// The horizontal centering margin between the button edge and the image,
    /// when the image is narrower than the button.
    private func imageHorizontalMargin(of button: NSStatusBarButton) -> CGFloat {
        let imageWidth = button.image?.size.width ?? button.bounds.width
        return max((button.bounds.width - imageWidth) / 2.0, 0)
    }

    /// The vertical centering margin between the button edge and the image,
    /// when the image is shorter than the button.
    private func imageVerticalMargin(of button: NSStatusBarButton) -> CGFloat {
        let imageHeight = button.image?.size.height ?? button.bounds.height
        return max((button.bounds.height - imageHeight) / 2.0, 0)
    }

    func getButtonFrame() -> NSRect? {
        return statusBarItem.button?.frame
    }

    func getButtonAppearance() -> NSAppearance? {
        return statusBarItem.button?.effectiveAppearance
    }

    func reloadShortcuts() {
        shortcutHelper.reload()
        spaceSwitcher.reloadShortcuts()
    }

    func updateStatusBar(withIcon icon: NSImage, withSpaces spaces: [Space]) {
        currentSpaces = spaces
        // update icon
        if let statusBarButton = statusBarItem.button {
            statusBarButton.image = icon
        }
        // update menu
        guard spaces.count > 0 else {
            return
        }
        removeDynamicMenuItems()
        // Build items grouped by display with a separator between displays.
        var itemsToInsert: [NSMenuItem] = []
        var lastDisplayID: String?
        let switchMap = Space.buildSwitchIndexMap(for: spaces)
        for space in spaces {
            if let last = lastDisplayID, last != space.displayID {
                itemsToInsert.append(NSMenuItem.separator())
            }
            let idx = switchMap[space.spaceID]
            // Positive indices are desktop numbers; -1 is F1 (fullscreen); nil is unswitchable
            let desktopNum: Int? = if let idx, idx > 0 { idx } else { nil }
            let isF1 = idx == -1
            itemsToInsert.append(makeSwitchToSpaceItem(space: space, desktopNumber: desktopNum, isF1: isF1))
            lastDisplayID = space.displayID
        }
        // No trailing separator needed — the fixed separator before the settings submenus handles it
        // Insert in order at index 2
        var insertIndex = 2
        for item in itemsToInsert { statusBarMenu.insertItem(item, at: insertIndex); insertIndex += 1 }
    }

    /// Remove all dynamic items between the about header (index 2) and the settings submenus.
    private func removeDynamicMenuItems() {
        let boundaryIdx = statusBarMenu.index(of: layoutMenuItem)
        let separatorIdx = boundaryIdx - 1
        if separatorIdx > 2 {
            for _ in 2..<separatorIdx { statusBarMenu.removeItem(at: 2) }
        }
    }

    /// Replace the space list with a grid view for Option+right-click.
    private func replaceDynamicItemsWithGrid() {
        removeDynamicMenuItems()
        let switchMap = Space.buildSwitchIndexMap(for: currentSpaces)
        let gridItem = NSMenuItem()
        let gridView = NSHostingView(rootView: SpaceGridMenuView(
            spaces: currentSpaces,
            onSwitch: { [weak self] tag in
                self?.statusBarMenu.cancelTracking()
                self?.handleSwitchTag(tag)
            },
            switchMap: switchMap,
            menuWidth: Constants.minMenuWidth
        ))
        gridView.frame.size = gridView.fittingSize
        gridView.sizingOptions = [.intrinsicContentSize]
        gridItem.view = gridView
        statusBarMenu.insertItem(gridItem, at: 2)
    }

    /// Restore the normal space list after the grid menu closes.
    private func restoreDynamicItemsAsList() {
        removeDynamicMenuItems()
        var itemsToInsert: [NSMenuItem] = []
        var lastDisplayID: String?
        let switchMap = Space.buildSwitchIndexMap(for: currentSpaces)
        for space in currentSpaces {
            if let last = lastDisplayID, last != space.displayID {
                itemsToInsert.append(NSMenuItem.separator())
            }
            let idx = switchMap[space.spaceID]
            let desktopNum: Int? = if let idx, idx > 0 { idx } else { nil }
            let isF1 = idx == -1
            itemsToInsert.append(makeSwitchToSpaceItem(space: space, desktopNumber: desktopNum, isF1: isF1))
            lastDisplayID = space.displayID
        }
        var insertIndex = 2
        for item in itemsToInsert { statusBarMenu.insertItem(item, at: insertIndex); insertIndex += 1 }
    }

    @objc func refreshSpaces(_ sender: AnyObject) {
        postRefreshNotification()
    }

    // MARK: - Quick Rename

    @objc func quickRenameCurrentSpace(_ sender: AnyObject) {
        showQuickRenamePanel()
    }

    func showQuickRenamePanel() {
        // Dismiss any existing panel
        quickRenamePanel?.close()
        quickRenamePanel = nil

        // Find the current space on the frontmost display
        let activeSpaces = currentSpaces.filter { $0.isCurrentSpace }
        guard !activeSpaces.isEmpty else { return }

        let currentSpace: Space
        if activeSpaces.count == 1 {
            currentSpace = activeSpaces[0]
        } else if let mainScreen = NSScreen.main,
                  let screenNumber = mainScreen.deviceDescription[
                      NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let mainDisplayID = CGDirectDisplayID(screenNumber.uint32Value)
            currentSpace = activeSpaces.first { space in
                let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, space.displayID as CFString)
                return CGDisplayGetDisplayIDFromUUID(uuid) == mainDisplayID
            } ?? activeSpaces[0]
        } else {
            currentSpace = activeSpaces[0]
        }

        let spaceID = currentSpace.spaceID
        let currentName = currentSpace.spaceName
        let currentColorHex = currentSpace.colorHex

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 1),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        panel.title = String(
            localized: "Rename Space \(currentSpace.spaceByDesktopID)")
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false

        let renameView = QuickRenameView(
            currentName: currentName,
            currentColorHex: currentColorHex,
            onRename: { [weak self] newName in
                self?.applyQuickRename(spaceID: spaceID, newName: newName)
                self?.quickRenamePanel?.close()
                self?.quickRenamePanel = nil
            },
            onColorChange: { [weak self] newColor in
                self?.applyColorChange(spaceID: spaceID, color: newColor)
            },
            onCancel: { [weak self] in
                self?.quickRenamePanel?.close()
                self?.quickRenamePanel = nil
            })
        let hostingView = NSHostingView(rootView: renameView)
        panel.contentView = hostingView

        // Position near the status bar item
        if let buttonFrame = statusBarItem.button?.window?.frame {
            let x = buttonFrame.midX - 170
            let y = buttonFrame.minY - 4
            panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        quickRenamePanel = panel
    }

    private func applyQuickRename(spaceID: String, newName: String) {
        let nameStore = SpaceNameStore.shared
        nameStore.update { stored in
            guard let info = stored[spaceID] else { return }
            stored[spaceID] = info.withName(newName)
        }
        postRefreshNotification()
    }

    private func applyColorChange(spaceID: String, color: NSColor?) {
        let nameStore = SpaceNameStore.shared
        nameStore.update { stored in
            guard let info = stored[spaceID] else { return }
            stored[spaceID] = info.withColor(color?.toHexString())
        }
        postRefreshNotification()
    }

    // MARK: - Settings Submenus

    func menuWillOpen(_ menu: NSMenu) {
        // Update row layout checkmarks
        for item in rowLayoutMenuItem.submenu?.items ?? [] {
            item.state = item.tag == rowLayout.rawValue ? .on : .off
        }
        // Rebuild icon size submenu: filter sizes based on two-row mode
        let layoutSubmenu = NSMenu()
        let availableSizes = rowLayout.isTwoRows
            ? IconSize.allCases.filter { Constants.sizesTwoRows[$0] != nil }
            : Array(IconSize.allCases)
        for mode in availableSizes {
            let item = NSMenuItem(title: mode.menuLabel, action: #selector(selectLayout(_:)), keyEquivalent: "")
            item.tag = mode.rawValue
            item.target = self
            item.state = mode == iconSize ? .on : .off
            layoutSubmenu.addItem(item)
        }
        layoutSubmenu.addItem(NSMenuItem.separator())
        let variableWidthItem = NSMenuItem(
            title: String(localized: "Variable width"),
            action: #selector(toggleVariableWidth), keyEquivalent: "")
        variableWidthItem.target = self
        variableWidthItem.state = useVariableWidth ? .on : .off
        layoutSubmenu.addItem(variableWidthItem)
        layoutMenuItem.submenu = layoutSubmenu
        for item in iconStyleMenuItem.submenu?.items ?? [] {
            if item.action == #selector(selectIconStyle(_:)) {
                item.state = item.tag == displayStyle.rawValue ? .on : .off
            } else if item.action == #selector(selectFont(_:)) {
                item.state = item.tag == fontDesign.rawValue ? .on : .off
            }
        }
        let bothNoDecoration = decorationActive.isNoDecoration && decorationInactive.isNoDecoration
        let shapesMatch = !bothNoDecoration
            && !decorationActive.isNoDecoration && !decorationInactive.isNoDecoration
            && decorationActive.shape == decorationInactive.shape
        let fillsMatch = !bothNoDecoration
            && !decorationActive.isNoDecoration && !decorationInactive.isNoDecoration
            && decorationActive.fill == decorationInactive.fill
        for item in iconShapeMenuItem.submenu?.items ?? [] {
            if item.action == #selector(selectIconShape(_:)) {
                if item.tag == IconShape.noDecoration.rawValue {
                    item.state = bothNoDecoration ? .on : .off
                } else {
                    item.state = (shapesMatch && item.tag == decorationActive.shape.rawValue) ? .on : .off
                }
            } else if item.action == #selector(selectIconFill(_:)) {
                item.state = (fillsMatch && item.tag == decorationActive.fill.rawValue) ? .on : .off
            }
        }
        for item in spacesShownMenuItem.submenu?.items ?? [] {
            if item.action == #selector(toggleShowFullscreenSpaces) {
                item.state = showFullscreenSpaces ? .on : .off
            } else if item.action == #selector(toggleShowMissionControl) {
                item.state = showMissionControl ? .on : .off
            } else if item.action == #selector(toggleShowNavArrows) {
                item.state = showNavArrows ? .on : .off
            } else {
                item.state = item.tag == visibleSpacesModeRaw ? .on : .off
            }
        }
    }

    @objc func selectRowLayout(_ sender: NSMenuItem) {
        guard let layout = RowLayout(rawValue: sender.tag) else { return }
        rowLayout = layout
        if layout.isTwoRows && Constants.sizesTwoRows[iconSize] == nil {
            switch iconSize {
            case .narrow, .compact:              iconSize = .compact
            case .medium:                        iconSize = .medium
            case .large, .extraLarge, .enormous:  iconSize = .large
            }
        }
        postRefreshNotification()
    }

    @objc func selectLayout(_ sender: NSMenuItem) {
        guard let mode = IconSize(rawValue: sender.tag) else { return }
        iconSize = mode
        postRefreshNotification()
    }

    @objc func toggleVariableWidth() {
        useVariableWidth.toggle()
        postRefreshNotification()
    }

    @objc func selectFont(_ sender: NSMenuItem) {
        guard let design = FontDesign(rawValue: sender.tag) else { return }
        fontDesign = design
        postRefreshNotification()
    }

    @objc func selectIconStyle(_ sender: NSMenuItem) {
        guard let style = IconText(rawValue: sender.tag) else { return }
        displayStyle = style
        postRefreshNotification()
    }

    @objc func selectIconShape(_ sender: NSMenuItem) {
        guard let shape = IconShape(rawValue: sender.tag) else { return }
        if shape == .noDecoration {
            saveLastDecoration()
            decorationActive = .noDecoration
            decorationInactive = .noDecoration
        } else {
            let activeFill = decorationActive.isNoDecoration
                ? (IconFill(rawValue: lastActiveFillRaw) ?? .bordered)
                : decorationActive.fill
            let inactiveFill = decorationInactive.isNoDecoration
                ? (IconFill(rawValue: lastInactiveFillRaw) ?? .bordered)
                : decorationInactive.fill
            decorationActive = decorationActive.withShape(shape).withFill(activeFill)
            decorationInactive = decorationInactive.withShape(shape).withFill(inactiveFill)
            saveLastDecoration()
        }
        postRefreshNotification()
    }

    @objc func selectIconFill(_ sender: NSMenuItem) {
        guard let fill = IconFill(rawValue: sender.tag) else { return }
        let activeShape = decorationActive.isNoDecoration
            ? (IconShape(rawValue: lastActiveShapeRaw) ?? .rectangular)
            : decorationActive.shape
        let inactiveShape = decorationInactive.isNoDecoration
            ? (IconShape(rawValue: lastInactiveShapeRaw) ?? .rectangular)
            : decorationInactive.shape
        decorationActive = decorationActive.withFill(fill).withShape(activeShape)
        decorationInactive = decorationInactive.withFill(fill).withShape(inactiveShape)
        saveLastDecoration()
        postRefreshNotification()
    }

    private func saveLastDecoration() {
        if !decorationActive.isNoDecoration {
            lastActiveShapeRaw = decorationActive.shape.rawValue
            lastActiveFillRaw = decorationActive.fill.rawValue
        }
        if !decorationInactive.isNoDecoration {
            lastInactiveShapeRaw = decorationInactive.shape.rawValue
            lastInactiveFillRaw = decorationInactive.fill.rawValue
        }
    }

    @objc func selectSpacesShown(_ sender: NSMenuItem) {
        visibleSpacesModeRaw = sender.tag
        postRefreshNotification()
    }

    @objc func toggleShowFullscreenSpaces() {
        showFullscreenSpaces.toggle()
        postRefreshNotification()
    }

    @objc func toggleShowMissionControl() {
        showMissionControl.toggle()
        postRefreshNotification()
    }

    @objc func toggleShowNavArrows() {
        showNavArrows.toggle()
        postRefreshNotification()
    }

    @objc func showPreferencesWindow(_ sender: AnyObject) {
        let hostedPrefsView = NSHostingView(rootView: PreferencesView())
        hostedPrefsView.sizingOptions = [.intrinsicContentSize]
        prefsWindow.contentView = hostedPrefsView

        // Observe tab changes to resize the window
        if tabChangeObserver == nil {
            tabChangeObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PreferencesTabChanged"),
                object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.prefsWindow.resizeToFitContent()
                }
            }
        }

        prefsWindow.resizeToFitContent(animate: false)
        prefsWindow.center()
        prefsWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func makeSwitchToSpaceItem(space: Space, desktopNumber: Int?, isF1: Bool = false) -> NSMenuItem {
        let spaceName = space.spaceName.isEmpty ? "-" : space.spaceName

        var shortcutKey = ""
        var mask = NSEvent.ModifierFlags()
        if let n = desktopNumber, let sc = shortcutHelper.shortcut(forDesktop: n) {
            shortcutKey = sc.keyEquivalent
            mask = sc.modifierFlags
        }

        let menuIcon = iconCreator.createMenuItemIcon(space: space, fraction: 0.6)
        let item = NSMenuItem(
            title: spaceName,
            action: #selector(switchToSpace(_:)),
            keyEquivalent: shortcutKey)
        item.keyEquivalentModifierMask = mask
        item.target = self
        item.tag = desktopNumber ?? -(space.spaceNumber)
        item.image = menuIcon
        let canChain = navigateAnywhere && space.isFullScreen
        if space.isCurrentSpace || (shortcutKey == "" && !isF1 && !canChain) {
            item.isEnabled = false
            if space.isCurrentSpace {
                item.state = .on // tick mark
            }
        }
        return item
    }

    @objc func switchToSpace(_ sender: NSMenuItem) {
        handleSwitchTag(sender.tag)
    }

    private func handleSwitchTag(_ tag: Int) {
        if tag >= 1 && tag <= Space.maxSwitchableDesktop {
            spaceSwitcher.switchToSpace(spaceNumber: tag, onError: flashStatusBar)
        } else if tag < 0 && navigateAnywhere {
            // Negative tag = -(spaceNumber) for spaces without a direct shortcut
            let targetSpaceNumber = -tag
            spaceSwitcher.navigateByChaining(
                targetSpaceNumber: targetSpaceNumber,
                spaces: currentSpaces,
                onError: flashStatusBar)
        } else if tag < 0 {
            // F1 with chaining disabled: send minus key shortcut
            if let sc = shortcutHelper.fullscreenShortcut {
                spaceSwitcher.sendFullscreenShortcut(sc)
            }
        }
    }

    // MARK: - SPUStandardUserDriverDelegate

    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // Update is available - show badge with version number
        DispatchQueue.main.async {
            self.updatesItem.title = String(localized: "Update available…")
            if #available(macOS 14.0, *) {
                let versionString = item.displayVersionString
                self.updatesItem.badge = NSMenuItemBadge(string: "v\(versionString)")
            }
        }
    }

    func hideBadge() {
        // Hide the 'available' badge in the menu
        DispatchQueue.main.async {
            self.updatesItem.title = String(localized: "Check for updates…")
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

// MARK: - Missing Shortcut Balloon

private struct MissingShortcutBalloonView: View {
    var kind: MissingShortcutKind
    var onConfigure: () -> Void

    private var imageName: String {
        switch kind {
        case .navigation: return "MCShortcutsNavigation"
        case .desktop:    return "MCShortcutsDesktops"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("No shortcut known")
                .font(.system(size: 13, weight: .medium))
            Text("Enable under Keyboard → Shortcuts → Mission Control:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("You are free to choose any shortcut key you like.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Button("Configure") {
                onConfigure()
            }
            .font(.system(size: 12))
        }
        .padding(14)
    }
}

