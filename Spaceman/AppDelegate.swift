//
//  AppDelegate.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var iconCreator: IconCreator!
    private var statusBar: StatusBar!
    private var spaceObserver: SpaceObserver!

    // Auto-compact: degrade visible spaces mode when the icon is evicted from the menu bar
    private var effectiveVisibleMode: VisibleSpacesMode? {
        didSet { statusBar?.effectiveVisibleMode = effectiveVisibleMode }
    }
    private var effectiveNeighborRadius: Int?
    private var lastSpaces: [Space] = []
    private var autoCompactEnabled = false
    private var occlusionObserver: NSObjectProtocol?
    private var safetyTimer: Timer?
    private var compactDebounceWorkItem: DispatchWorkItem?

    static var activeSpaceIDs: Set<String> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Legacy settings migration - can be removed in future versions
        performLegacyMigrations()

        iconCreator = IconCreator()

        statusBar = StatusBar()
        statusBar.iconCreator = iconCreator

        spaceObserver = SpaceObserver()
        spaceObserver.delegate = self
        spaceObserver.updateSpaceInformation()

        NSApp.activate(ignoringOtherApps: true)
        KeyboardShortcuts.onKeyUp(for: .refresh) { [] in
            self.spaceObserver.updateSpaceInformation()
        }
        KeyboardShortcuts.onKeyUp(for: .preferences) { [] in
            self.statusBar.showPreferencesWindow(self)
        }

        // Listen for AppleScript "open preferences" notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferencesFromScript),
            name: NSNotification.Name("OpenPreferences"),
            object: nil)

        // Auto-compact: observe the status bar window's occlusion state
        // The window may not exist yet at launch; try after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.autoCompactEnabled = true
            self.setupOcclusionObserver()
            self.compactIfEvicted()
            // Safety-net timer in case the notification doesn't fire
            self.safetyTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                self?.compactIfEvicted()
            }
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

    // MARK: - Auto-compact

    private func renderIcon(for spaces: [Space]) {
        let buttonAppearance = statusBar.getButtonAppearance()
        let icon = iconCreator.getIcon(for: spaces, buttonFrame: nil,
                                        appearance: buttonAppearance,
                                        visibleModeOverride: effectiveVisibleMode,
                                        neighborRadiusOverride: effectiveNeighborRadius)
        statusBar.updateStatusBar(withIcon: icon, withSpaces: spaces)

        // Set up the occlusion observer once the window exists
        if occlusionObserver == nil {
            setupOcclusionObserver()
        }
    }

    private func setupOcclusionObserver() {
        guard occlusionObserver == nil,
              let window = statusBar.statusBarWindow() else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.compactIfEvicted()
        }
    }

    /// Compact one level if the icon has been evicted. Called after every render
    /// and periodically by the visibility timer to catch external evictions.
    /// Debounced so transient occlusion changes (e.g., during a space swipe
    /// animation) don't trigger unnecessary compaction.
    private func compactIfEvicted() {
        guard autoCompactEnabled, !statusBar.isIconVisible() else { return }

        compactDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performCompaction()
        }
        compactDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    private func performCompaction() {
        guard autoCompactEnabled, !statusBar.isIconVisible() else { return }

        let currentMode = effectiveVisibleMode
            ?? VisibleSpacesMode(rawValue: UserDefaults.standard.integer(forKey: "visibleSpacesMode"))
            ?? .all
        let currentRadius = effectiveNeighborRadius
            ?? (currentMode == .neighbors ? max(1, UserDefaults.standard.integer(forKey: "neighborRadius")) : 0)

        switch currentMode {
        case .all:
            effectiveVisibleMode = .neighbors
            effectiveNeighborRadius = 3
        case .neighbors where currentRadius > 1:
            effectiveVisibleMode = .neighbors
            effectiveNeighborRadius = currentRadius - 1
        case .neighbors:
            effectiveVisibleMode = .currentOnly
            effectiveNeighborRadius = nil
        case .currentOnly:
            return
        }

        renderIcon(for: lastSpaces)
    }

    // MARK: - Legacy Settings Migration
    private func performLegacyMigrations() {
        // Remove obsolete UserDefaults keys
        UserDefaults.standard.removeObject(forKey: "spaceNameCache")

        // Migrate legacy hideInactiveSpaces to visibleSpacesMode
        if UserDefaults.standard.object(forKey: "visibleSpacesMode") == nil {
            let hideInactiveSpaces = UserDefaults.standard.bool(forKey: "hideInactiveSpaces")
            if hideInactiveSpaces {
                UserDefaults.standard.set(VisibleSpacesMode.currentOnly.rawValue, forKey: "visibleSpacesMode")
            }
        }

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
    }
}

extension AppDelegate: SpaceObserverDelegate {
    func didUpdateSpaces(spaces: [Space]) {
        lastSpaces = spaces
        AppDelegate.activeSpaceIDs = Set(spaces.map { $0.spaceID })
        NotificationCenter.default.post(name: NSNotification.Name("ActiveSpacesChanged"), object: nil)

        effectiveVisibleMode = nil
        effectiveNeighborRadius = nil
        renderIcon(for: spaces)
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
        PreferencesView(parentWindow: nil)
    }
}
