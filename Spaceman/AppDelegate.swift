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
    @AppStorage("showHUD") private var showHUD = false
    @AppStorage("autoRefreshSpaces") private var autoRefreshSpaces = false
    @AppStorage("mainDisplayOnly") private var mainDisplayOnly = false

    private var iconCreator: IconCreator!
    private var statusBar: StatusBar!
    private var spaceObserver: SpaceObserver!
    private var hudPanel = HUDPanel()
    private var autoRefreshTimer: Timer?
    private var currentSpaces: [Space] = []

    // Auto-shrink state
    private var shrinkLevel: ShrinkLevel = .none
    private var lastSpaces: [Space] = []
    private var occlusionObserver: NSObjectProtocol?
    private var suppressOcclusionUntil: Date = .distantPast

    static var activeSpaceIDs: Set<String> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Legacy settings migration - can be removed in future versions
        LegacyMigrations.perform()

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

        // Auto-refresh timer — lives here so it survives the preferences window closing.
        if autoRefreshSpaces { startAutoRefreshTimer() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoRefreshSettingChanged),
            name: UserDefaults.didChangeNotification,
            object: nil)
    }

    private func startAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: 5, repeats: true) { _ in
            NotificationCenter.default.post(name: autoRefreshTriggeredName, object: nil)
        }
    }

    private func stopAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    @objc private func autoRefreshSettingChanged() {
        if autoRefreshSpaces && autoRefreshTimer == nil {
            startAutoRefreshTimer()
        } else if !autoRefreshSpaces && autoRefreshTimer != nil {
            stopAutoRefreshTimer()
        }
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

        // Filter to main display when enabled
        let displaySpaces: [Space]
        if mainDisplayOnly,
           let mainID = Self.mainDisplayID(from: spaces) {
            displaySpaces = spaces.filter { $0.displayID == mainID }
        } else {
            displaySpaces = spaces
        }

        let buttonAppearance = statusBar.getButtonAppearance()
        statusBar.isAppIconMode = (shrinkLevel == .icon)

        switch shrinkLevel {
        case .none:
            let icon = iconCreator.getIcon(for: displaySpaces, appearance: buttonAppearance)
            statusBar.updateStatusBar(withIcon: icon, withSpaces: displaySpaces)
        case .shrunken:
            // Override size, text style, and visibility — but not row layout,
            // which stays at the user's preference (two-row is more compact).
            let overrides = ShrinkOverrides(
                iconSize: .compact, iconText: .numbers,
                showFullscreenSpaces: false, showNavArrows: false, showMissionControl: false)
            let icon = iconCreator.getIcon(for: displaySpaces, appearance: buttonAppearance,
                                            shrinkOverrides: overrides)
            statusBar.updateStatusBar(withIcon: icon, withSpaces: displaySpaces)
        case .icon:
            if let appIcon = NSApp.applicationIconImage {
                let menuBarHeight = NSStatusBar.system.thickness
                let scaled = NSImage(size: NSSize(width: menuBarHeight, height: menuBarHeight))
                scaled.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: menuBarHeight, height: menuBarHeight))
                scaled.unlockFocus()
                statusBar.updateStatusBar(withIcon: scaled, withSpaces: displaySpaces)
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

    /// The display UUID of the main display (menu bar).
    private static func mainDisplayID(
        from spaces: [Space]
    ) -> String? {
        let mainCGID = CGMainDisplayID()
        let displayIDs = Set(spaces.map { $0.displayID })
        for displayID in displayIDs {
            guard let uuid = CFUUIDCreateFromString(
                kCFAllocatorDefault,
                displayID as CFString)
            else { continue }
            if CGDisplayGetDisplayIDFromUUID(uuid)
                == mainCGID {
                return displayID
            }
        }
        return nil
    }
}

extension AppDelegate: SpaceObserverDelegate {
    func didUpdateSpaces(spaces: [Space], trigger: SpaceUpdateTrigger) {
        currentSpaces = spaces

        if let displayID = HUDPanel.targetDisplayID(
            spaces: spaces, previousSpaces: lastSpaces,
            trigger: trigger, showHUD: showHUD),
           let screen = HUDPanel.screen(forDisplayID: displayID) {
            let displaySpaces = spaces.filter { $0.displayID == displayID && !$0.isFullScreen }
            hudPanel.show(spaces: displaySpaces, on: screen)
        }

        statusBar.reloadShortcuts()
        lastSpaces = spaces

        // Reset auto-shrink so the full icon gets a chance to render.
        // Auto-refresh preserves the current shrink state — if the icon still
        // doesn't fit, shrinkIfEvicted() will shrink it back down.
        if trigger.resetsAutoShrink {
            shrinkLevel = .none
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
    @StateObject private var tabState = PreferencesTabState()
    var body: some View {
        PreferencesView(tabState: tabState)
    }
}
