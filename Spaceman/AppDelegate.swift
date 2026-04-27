//
//  AppDelegate.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    @AppStorage("autoShrink") private var autoShrink = true

    private var iconCreator: IconCreator!
    private var statusBar: StatusBar!
    private var spaceObserver: SpaceObserver!
    private var currentSpaces: [Space] = []

    // Auto-shrink state
    private var shrinkLevel: ShrinkLevel = .none
    private var lastSpaces: [Space] = []
    private var occlusionObserver: NSObjectProtocol?
    private var suppressOcclusionUntil: Date = .distantPast

    static var activeSpaceIDs: Set<String> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Legacy settings migration - can be removed in future versions
        Self.performLegacyMigrations()

        iconCreator = IconCreator()

        statusBar = StatusBar()
        statusBar.iconCreator = iconCreator

        spaceObserver = SpaceObserver()
        spaceObserver.delegate = self
        spaceObserver.updateSpaceInformation()

        NSApp.activate(ignoringOtherApps: true)
        KeyboardShortcuts.onKeyUp(for: .refresh) { [] in
            postSettingsChanged()
        }
        KeyboardShortcuts.onKeyUp(for: .preferences) { [] in
            self.statusBar.showPreferencesWindow(self)
        }
        KeyboardShortcuts.onKeyUp(for: .quickRename) { [] in
            self.statusBar.showQuickRenamePanel()
        }

        // Listen for AppleScript "open preferences" notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferencesFromScript),
            name: NSNotification.Name("OpenPreferences"),
            object: nil)

        // Auto-shrink: set up occlusion observer after a short delay
        // (the status bar window may not exist yet at launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupOcclusionObserver()
            self.shrinkIfEvicted()
        }

        // Auto-shrink resets happen in didUpdateSpaces(trigger:) —
        // SettingsChanged triggers .userRefresh, which resets shrinkLevel there.
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // MARK: - Public Methods for Scripts/Shortcuts
    public func showPreferencesWindow() {
        statusBar.showPreferencesWindow(self)
    }

    @objc private func openPreferencesFromScript() {
        statusBar.showPreferencesWindow(self)
    }

    // MARK: - AppleScript Properties

    func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        return key == "currentSpaceNumber" || key == "currentSpaceName"
            || key == "displayCount" || key == "currentDisplayNumber"
    }

    @objc var currentSpaceNumber: Int {
        return currentSpaceOnFrontmostDisplay()?.spaceNumber ?? 0
    }

    @objc var currentSpaceName: String {
        return currentSpaceOnFrontmostDisplay()?.spaceName ?? ""
    }

    @objc var displayCount: Int {
        return orderedDisplayIDs().count
    }

    @objc var currentDisplayNumber: Int {
        let displayIDs = orderedDisplayIDs()
        guard let frontmostDisplayID = frontmostDisplayID() else { return 0 }
        if let index = displayIDs.firstIndex(of: frontmostDisplayID) {
            return index + 1
        }
        return 0
    }

    private func orderedDisplayIDs() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        // swiftlint:disable for_where
        // insert() mutates `seen` as a side effect; `where` can't do that
        for space in currentSpaces {
            if seen.insert(space.displayID).inserted {
                result.append(space.displayID)
            }
        }
        // swiftlint:enable for_where
        return result
    }

    private func frontmostDisplayID() -> String? {
        guard let mainScreen = NSScreen.main,
              let screenNumber = mainScreen.deviceDescription[
                  NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        let mainCGDisplayID = CGDirectDisplayID(screenNumber.uint32Value)
        for displayID in orderedDisplayIDs() {
            let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, displayID as CFString)
            if CGDisplayGetDisplayIDFromUUID(uuid) == mainCGDisplayID {
                return displayID
            }
        }
        return nil
    }

    private func currentSpaceOnFrontmostDisplay() -> Space? {
        let activeSpaces = currentSpaces.filter { $0.isCurrentSpace }
        guard !activeSpaces.isEmpty else { return nil }
        if activeSpaces.count == 1 { return activeSpaces.first }

        if let displayID = frontmostDisplayID() {
            return activeSpaces.first { $0.displayID == displayID }
        }

        return activeSpaces.first
    }

    // MARK: - Auto-shrink
    //
    // When the status bar icon is too wide for the menu bar, macOS hides it
    // (occlusion). Auto-shrink detects this and progressively reduces the icon:
    //
    //   .none → .shrunken → .icon
    //
    // .none:     Full rendering with all user settings.
    // .shrunken: Numbers only, compact size, no fullscreen/arrows/MC.
    //            Row layout (single/two-row) is preserved from user settings.
    // .icon:     Static Spaceman app icon — the smallest possible representation.
    //
    // The level resets to .none on topology changes, user refresh, or space
    // switches (via didUpdateSpaces). Auto-refresh does not reset it.
    //
    // Occlusion detection has two paths:
    // 1. NSWindow.didChangeOcclusionStateNotification (primary)
    // 2. A scheduled fallback check after each render, because the notification
    //    may fire during the suppression window and get ignored.
    //    Timing: 1.1s for .none (conservative), 0.4s for .shrunken (faster,
    //    since a false trigger to .icon is harmless).

    /// Renders the status bar icon at the current shrinkLevel.
    private func renderIcon(for spaces: [Space]) {
        // After setting a new image, macOS may briefly report the item as occluded.
        // Use a shorter suppression for .shrunken → .icon because the size change
        // is small and a false trigger to .icon (the final fallback) is harmless.
        let suppressDuration: TimeInterval = shrinkLevel == .shrunken ? 0.3 : 1.0
        let fallbackDelay: TimeInterval = suppressDuration + 0.1
        suppressOcclusionUntil = Date().addingTimeInterval(suppressDuration)

        let buttonAppearance = statusBar.getButtonAppearance()
        statusBar.isAppIconMode = (shrinkLevel == .icon)

        switch shrinkLevel {
        case .none:
            let icon = iconCreator.getIcon(for: spaces, appearance: buttonAppearance)
            statusBar.updateStatusBar(withIcon: icon, withSpaces: spaces)
        case .shrunken:
            // Override size, text style, and visibility — but not row layout,
            // which stays at the user's preference (two-row is more compact).
            let overrides = ShrinkOverrides(
                iconSize: .compact, displayStyle: .numbers,
                showFullscreenSpaces: false, showNavArrows: false, showMissionControl: false)
            let icon = iconCreator.getIcon(for: spaces, appearance: buttonAppearance,
                                            shrinkOverrides: overrides)
            statusBar.updateStatusBar(withIcon: icon, withSpaces: spaces)
        case .icon:
            if let appIcon = NSApp.applicationIconImage {
                let menuBarHeight = NSStatusBar.system.thickness
                let scaled = NSImage(size: NSSize(width: menuBarHeight, height: menuBarHeight))
                scaled.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: menuBarHeight, height: menuBarHeight))
                scaled.unlockFocus()
                statusBar.updateStatusBar(withIcon: scaled, withSpaces: spaces)
            }
        }

        if occlusionObserver == nil {
            setupOcclusionObserver()
        }

        // Schedule a fallback occlusion check after the suppression window.
        // The primary path (didChangeOcclusionStateNotification) may have fired
        // during suppression and been ignored — this ensures we still react.
        if autoShrink && shrinkLevel != .icon {
            DispatchQueue.main.asyncAfter(deadline: .now() + fallbackDelay) { [weak self] in
                self?.shrinkIfEvicted()
            }
        }
    }

    /// Observes the status bar window's occlusion state. When macOS hides the
    /// icon (e.g., not enough room), this triggers shrinkIfEvicted().
    private func setupOcclusionObserver() {
        guard occlusionObserver == nil,
              let window = statusBar.statusBarWindow() else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.shrinkIfEvicted()
        }
    }

    /// If the icon is occluded and we're not in the suppression window,
    /// advance to the next shrink level and re-render.
    private func shrinkIfEvicted() {
        guard autoShrink,
              !statusBar.isIconVisible(),
              Date() >= suppressOcclusionUntil else { return }

        switch shrinkLevel {
        case .none:
            shrinkLevel = .shrunken
            renderIcon(for: lastSpaces)
        case .shrunken:
            shrinkLevel = .icon
            renderIcon(for: lastSpaces)
        case .icon:
            break
        }
    }

    // MARK: - Legacy Settings Migration
    /// Removes the keys that `performLegacyMigrations()` migrates *to*.
    /// Call this before restoring a backup and re-running migrations, so the
    /// migration guards (`if object(forKey:) == nil`) don't skip over old-format
    /// keys present in the backup. Must be kept in sync with `performLegacyMigrations()`.
    static func resetMigratedKeys() {
        let keys = [
            "visibleSpacesMode", "restartNumberingByDisplay", "horizontalDirection",
            "useVariableWidth", "decorationActive", "decorationInactive",
            "iconSize", "rowLayout", "showFullscreenSpaces"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func performLegacyMigrations() {
        // Remove obsolete UserDefaults keys
        UserDefaults.standard.removeObject(forKey: "spaceNameCache")

        // Migrate legacy hideInactiveSpaces to visibleSpacesMode
        if UserDefaults.standard.object(forKey: "visibleSpacesMode") == nil {
            let hideInactiveSpaces = UserDefaults.standard.bool(forKey: "hideInactiveSpaces")
            let newValue: Int = hideInactiveSpaces
                ? VisibleSpacesMode.currentOnly.rawValue
                : VisibleSpacesMode.all.rawValue
            UserDefaults.standard.set(newValue, forKey: "visibleSpacesMode")
        }
        UserDefaults.standard.removeObject(forKey: "hideInactiveSpaces")

        // Migrate restartNumberingByDesktop to restartNumberingByDisplay
        if UserDefaults.standard.object(forKey: "restartNumberingByDisplay") == nil {
            let oldValue = UserDefaults.standard.bool(forKey: "restartNumberingByDesktop")
            UserDefaults.standard.set(oldValue, forKey: "restartNumberingByDisplay")
            UserDefaults.standard.removeObject(forKey: "restartNumberingByDesktop")
        }

        // Migrate reverseDisplayOrder to horizontalDirection
        if UserDefaults.standard.object(forKey: "horizontalDirection") == nil {
            let oldReverseDisplayOrder = UserDefaults.standard.bool(forKey: "reverseDisplayOrder")
            let newValue: Int = oldReverseDisplayOrder
                ? HorizontalDirection.reverseOrder.rawValue
                : HorizontalDirection.defaultOrder.rawValue
            UserDefaults.standard.set(newValue, forKey: "horizontalDirection")
            UserDefaults.standard.removeObject(forKey: "reverseDisplayOrder")
        }

        // Migrate useMinIconWidth (inverted bool) to useVariableWidth
        if UserDefaults.standard.object(forKey: "useVariableWidth") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "useMinIconWidth") as? Bool {
            UserDefaults.standard.set(!oldValue, forKey: "useVariableWidth")
            UserDefaults.standard.removeObject(forKey: "useMinIconWidth")
        }

        // Migrate displayStyle + inactiveStyle → decoration
        if UserDefaults.standard.object(forKey: "decorationActive") == nil {
            let oldIconText = UserDefaults.standard.integer(forKey: "displayStyle")
            let oldInactiveStyle = UserDefaults.standard.integer(forKey: "inactiveStyle")

            if oldIconText == 1 {
                // Old "bare numbers" (raw value 1) → bare text decoration + numbers display style
                UserDefaults.standard.set(IconStyle.noDecoration.rawValue, forKey: "decorationActive")
                UserDefaults.standard.set(IconStyle.noDecoration.rawValue, forKey: "decorationInactive")
                UserDefaults.standard.set(IconText.numbers.rawValue, forKey: "displayStyle")
            } else {
                UserDefaults.standard.set(IconStyle.filledRounded.rawValue, forKey: "decorationActive")
                if oldInactiveStyle == 0 { // bordered
                    UserDefaults.standard.set(IconStyle.borderedRounded.rawValue, forKey: "decorationInactive")
                } else { // dimmed (1) or default
                    UserDefaults.standard.set(IconStyle.filledRounded.rawValue, forKey: "decorationInactive")
                }
            }
            UserDefaults.standard.removeObject(forKey: "inactiveStyle")
        }

        // Migrate layoutMode=0 (old .dualRows) to rowLayout + compact size
        if UserDefaults.standard.object(forKey: "layoutMode") != nil,
           UserDefaults.standard.integer(forKey: "layoutMode") == 0 {
            UserDefaults.standard.set(RowLayout.twoRowsByColumn.rawValue, forKey: "rowLayout")
            UserDefaults.standard.set(IconSize.compact.rawValue, forKey: "layoutMode")
        }

        // Migrate dualRows + dualRowFillOrder → rowLayout
        if UserDefaults.standard.object(forKey: "rowLayout") == nil,
           UserDefaults.standard.object(forKey: "dualRows") != nil {
            let dualRows = UserDefaults.standard.bool(forKey: "dualRows")
            if dualRows {
                let fillOrder = UserDefaults.standard.integer(forKey: "dualRowFillOrder")
                let newValue = fillOrder == 1
                    ? RowLayout.twoRowsByRow.rawValue
                    : RowLayout.twoRowsByColumn.rawValue
                UserDefaults.standard.set(newValue, forKey: "rowLayout")
            } else {
                UserDefaults.standard.set(RowLayout.singleRow.rawValue, forKey: "rowLayout")
            }
            UserDefaults.standard.removeObject(forKey: "dualRows")
            UserDefaults.standard.removeObject(forKey: "dualRowFillOrder")
        }

        // Migrate layoutMode (old key + raw values) to iconSize (new key + raw values)
        // Old: compact=1, medium=2, large=3, extraLarge=4, narrow=5, enormous=6
        // New: narrow=0, compact=1, medium=2, large=3, extraLarge=4, enormous=5
        if UserDefaults.standard.object(forKey: "iconSize") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "layoutMode") as? Int {
            let newValue: Int
            switch oldValue {
            case 5:  newValue = IconSize.narrow.rawValue    // 5 → 0
            case 6:  newValue = IconSize.enormous.rawValue  // 6 → 5
            default: newValue = oldValue                    // 1–4 unchanged
            }
            UserDefaults.standard.set(newValue, forKey: "iconSize")
            UserDefaults.standard.removeObject(forKey: "layoutMode")
        }

        // Migrate hideFullscreenSpaces (inverted bool) to showFullscreenSpaces
        if UserDefaults.standard.object(forKey: "showFullscreenSpaces") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "hideFullscreenSpaces") as? Bool {
            UserDefaults.standard.set(!oldValue, forKey: "showFullscreenSpaces")
            UserDefaults.standard.removeObject(forKey: "hideFullscreenSpaces")
        }
    }
}

extension AppDelegate: SpaceObserverDelegate {
    func didUpdateSpaces(spaces: [Space], trigger: SpaceUpdateTrigger) {
        currentSpaces = spaces
        statusBar.reloadShortcuts()
        lastSpaces = spaces

        // Reset auto-shrink so the full icon gets a chance to render.
        // Auto-refresh preserves the current shrink state — if the icon still
        // doesn't fit, shrinkIfEvicted() will shrink it back down.
        switch trigger {
        case .spaceSwitch, .topologyChange, .userRefresh:
            shrinkLevel = .none
        case .autoRefresh:
            break
        }

        renderIcon(for: spaces)

        AppDelegate.activeSpaceIDs = Set(spaces.map { $0.spaceID })
        NotificationCenter.default.post(name: NSNotification.Name("ActiveSpacesChanged"), object: nil)
    }
}

@main
struct SpacemanApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Note:
    // - This is SwiftUI's SceneBuilder (var body: some Scene).
    // - Some toolchain combinations do not support runtime control flow (e.g., if/#available)
    //   inside the SceneBuilder closure, which may trigger:
    //   "closure containing control flow statement cannot be used with result builder 'SceneBuilder'".
    // - To maximize compatibility, return a single expression here and move availability checks
    //   into a regular function.
    var body: some Scene {
        makeSettingsScene()
    }

    // Note:
    // - Perform the #available(macOS 15) check in a regular function rather than inside
    //   the SceneBuilder closure to avoid result‑builder control‑flow limitations.
    // - Apply .defaultLaunchBehavior(.suppressed) only on macOS 15+.
    private func makeSettingsScene() -> some Scene {
        if #available(macOS 15.0, *) {
            return Settings {
                SettingsView()
            }
            .defaultLaunchBehavior(.suppressed)
        } else {
            return Settings {
                SettingsView()
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        PreferencesView()
    }
}
