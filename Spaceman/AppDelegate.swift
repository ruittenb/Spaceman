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
    }
}

extension AppDelegate: SpaceObserverDelegate {
    func didUpdateSpaces(spaces: [Space]) {
        let buttonFrame = statusBar.getButtonFrame()
        let icon = iconCreator.getIcon(for: spaces, buttonFrame: buttonFrame)
        statusBar.updateStatusBar(withIcon: icon, withSpaces: spaces)

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
        PreferencesView(parentWindow: nil)
    }
}
