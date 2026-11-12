//
//  AppDelegate.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import SwiftUI
import KeyboardShortcuts
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {

    @AppStorage("showHUD") private var showHUD = false
    @AppStorage("autoRefreshSpaces") private var autoRefreshSpaces = false
    @AppStorage("autoShrink") private var autoShrink = true
    @AppStorage("mainDisplayOnly") private var mainDisplayOnly = false

    private var iconCreator: IconCreator!
    private var statusBar: StatusBar!
    private var spaceObserver: SpaceObserver!
    private var windowMover: WindowMover!
    private var hudPanel = HUDPanel()
    private var missionControlLabels: MissionControlLabels!
    private var autoRefreshTimer: Timer?
    private var currentSpaces: [Space] = []
    private var previousSpaceID: String?

    // Fit-to-width state
    private var fittedSize: IconSize?   // nil = the user's chosen size
    private var budget: CGFloat?        // measured room for the icon, nil = unknown
    private var lastIconWidth: CGFloat = 0
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
        windowMover = WindowMover()

        missionControlLabels = MissionControlLabels()

        NSApp.activate(ignoringOtherApps: true)
        registerKeyboardShortcuts()

        // Listen for AppleScript "open preferences" notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferencesFromScript),
            name: NSNotification.Name("OpenPreferences"),
            object: nil)

        // Re-register shortcuts after preferences are restored from backup
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesRestored),
            name: preferencesRestoredName,
            object: nil)

        // Fit-to-width: set up occlusion observer after a short delay
        // (the status bar window may not exist yet at launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupOcclusionObserver()
            self.shrinkIfEvicted()
        }

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
        windowMover?.cancelMove()
    }

    // MARK: - Public Methods for Scripts/Shortcuts
    public func showPreferencesWindow() {
        statusBar.showPreferencesWindow(self)
    }

    @objc private func openPreferencesFromScript() {
        statusBar.showPreferencesWindow(self)
    }

    @objc private func handlePreferencesRestored() {
        registerKeyboardShortcuts()
    }

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .refresh) {
            postSettingsChanged()
        }
        KeyboardShortcuts.onKeyUp(for: .preferences) { [weak self] in
            guard let self = self else { return }
            self.statusBar.showPreferencesWindow(self)
        }
        KeyboardShortcuts.onKeyUp(for: .quickRename) { [weak self] in
            self?.statusBar.showQuickRenamePanel()
        }
        KeyboardShortcuts.onKeyUp(for: .switchUp) { [weak self] in
            self?.statusBar.switchVertical(direction: -1)
        }
        KeyboardShortcuts.onKeyUp(for: .switchDown) { [weak self] in
            self?.statusBar.switchVertical(direction: 1)
        }
        KeyboardShortcuts.onKeyUp(for: .switchBack) { [weak self] in
            self?.switchToPreviousSpace()
        }
        KeyboardShortcuts.onKeyUp(for: .moveWindowToPreviousSpace) { [weak self] in
            self?.moveFocusedWindow(.previous)
        }
        KeyboardShortcuts.onKeyUp(for: .moveWindowToNextSpace) { [weak self] in
            self?.moveFocusedWindow(.next)
        }
    }

    private func switchToPreviousSpace() {
        guard let targetSpaceID = previousSpaceID,
              let targetSpace = currentSpaces.first(where: { $0.spaceID == targetSpaceID }),
              !targetSpace.isCurrentSpace else {
            return
        }
        statusBar.switchToSpaceByID(targetSpaceID)
    }

    private func moveFocusedWindow(_ direction: WindowMoveDirection) {
        windowMover.move(
            direction,
            spaces: currentSpaces,
            switchToSpace: { [weak self] spaceID in
                self?.statusBar.switchToSpaceByID(spaceID)
            },
            onError: { [weak self] error in
                self?.showWindowMoveError(error)
            })
    }

    private func showWindowMoveError(_ error: WindowMoveError) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Couldn’t Move Window")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: String(localized: "Dismiss"))
        if error.canOpenRelevantSettings {
            alert.addButton(withTitle: String(localized: "System Settings…"))
        }

        let response = alert.runModal()
        if response == .alertSecondButtonReturn,
           let url = error.settingsURL {
            NSWorkspace.shared.open(url)
        }
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

    // MARK: - Fit-to-width
    //
    // The menu bar has a fixed amount of room to the left of the status item,
    // and macOS simply hides an item that does not fit. Fit-to-width measures
    // that room and renders the largest icon size that fits inside it, so the
    // space names are always shown in full. The text style, row layout and
    // names are never changed - only the size.
    //
    // The budget is the distance from the right edge of our own status item
    // to the left edge of the usable menu bar area (right of the notch on
    // notched Macs). Items to our right keep their positions when our item
    // changes width, so this measurement is stable.
    //
    // Occlusion is kept only as a backstop for the first render, before the
    // status item window exists and a measurement is possible.

    private static let fitLog = Logger(
        subsystem: Constants.AppInfo.bundleId, category: "fit")

    /// The user's chosen icon size, read fresh from UserDefaults because
    /// @AppStorage on an NSObject does not observe writes from Preferences.
    private var userIconSize: IconSize {
        guard let raw = UserDefaults.standard.object(forKey: "iconSize") as? Int,
              let size = IconSize(rawValue: raw) else { return .medium }
        return size
    }

    private var isTwoRowLayout: Bool {
        let raw = UserDefaults.standard.integer(forKey: "rowLayout")
        return (RowLayout(rawValue: raw) ?? .singleRow).isTwoRows
    }

    /// The widest the icon may be before macOS hides the status item: the gap
    /// between our item's right edge and the start of the usable menu bar.
    /// Returns nil while the item is hidden or not yet placed, because the
    /// window frame is only meaningful for a visible item.
    private func measureBudget() -> CGFloat? {
        guard let window = statusBar.statusBarWindow(),
              statusBar.isIconVisible() else { return nil }
        let screen = window.screen ?? NSScreen.main
        guard let screen = screen else { return nil }
        let leftBound = screen.auxiliaryTopRightArea?.minX ?? screen.frame.minX
        let budget = window.frame.maxX - leftBound
        return budget > 0 ? budget : nil
    }

    /// Renders the status bar icon at the largest size that fits the budget.
    private func renderIcon(for spaces: [Space]) {
        // After setting a new image, macOS may briefly report the item as
        // occluded. Only the first-render backstop consults occlusion.
        suppressOcclusionUntil = Date().addingTimeInterval(1.0)

        // Filter to main display when enabled
        let displaySpaces: [Space]
        if mainDisplayOnly,
           let mainID = Self.mainDisplayID(from: spaces) {
            displaySpaces = spaces.filter { $0.displayID == mainID }
        } else {
            displaySpaces = spaces
        }

        if let measured = measureBudget() { budget = measured }

        let buttonAppearance = statusBar.getButtonAppearance()

        let size: IconSize
        let icon: NSImage
        if autoShrink {
            // With a measured budget, start from the user's size every time so
            // the icon grows back when room frees up. Without one, keep the
            // size the occlusion backstop settled on.
            var currentSize = budget == nil ? (fittedSize ?? userIconSize) : userIconSize
            var currentIcon = iconCreator.getIcon(for: displaySpaces, appearance: buttonAppearance,
                                                   sizeOverride: currentSize)

            if let budget = budget {
                while currentIcon.size.width > budget,
                      let smaller = currentSize.nextSmaller(twoRows: isTwoRowLayout) {
                    currentSize = smaller
                    currentIcon = iconCreator.getIcon(for: displaySpaces, appearance: buttonAppearance,
                                                       sizeOverride: currentSize)
                }
                Self.fitLog.log("""
                    fit: budget=\(Int(budget)) width=\(Int(currentIcon.size.width)) \
                    size=\(currentSize.rawValue) user=\(self.userIconSize.rawValue)
                    """)
            }
            fittedSize = currentSize == userIconSize ? nil : currentSize
            size = currentSize
            icon = currentIcon
        } else {
            // Auto-shrink disabled: always use the user's chosen size
            size = userIconSize
            icon = iconCreator.getIcon(for: displaySpaces, appearance: buttonAppearance,
                                        sizeOverride: size)
            fittedSize = nil
        }
        lastIconWidth = icon.size.width

        statusBar.updateStatusBar(withIcon: icon, withSpaces: displaySpaces)

        if occlusionObserver == nil {
            setupOcclusionObserver()
        }

        // Re-check once the item has been laid out: on the first render no
        // measurement was possible yet, and a measured budget can be too
        // generous if another item sits to our left.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.shrinkIfEvicted()
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

    /// Backstop: the item is hidden, so whatever we rendered was too wide.
    /// Tighten the budget below that width and re-render, which picks the
    /// largest size that fits underneath it. Never changes the text.
    private func shrinkIfEvicted() {
        guard autoShrink,
              !statusBar.isIconVisible(),
              Date() >= suppressOcclusionUntil else { return }

        let ceiling = lastIconWidth - 1
        if let current = budget, current <= ceiling {
            // Already budgeted below this width and still hidden: step the
            // size down directly so we keep making progress.
            guard let smaller = (fittedSize ?? userIconSize).nextSmaller(twoRows: isTwoRowLayout)
            else { return }
            fittedSize = smaller
            budget = nil
            Self.fitLog.log("evicted: stepping down to size=\(smaller.rawValue)")
        } else {
            budget = ceiling
            Self.fitLog.log("evicted: budget tightened to \(Int(ceiling))")
        }
        renderIcon(for: lastSpaces)
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
        // Track the previous active space - only when the space actually changes
        let oldCurrent = currentSpaces.first(where: { $0.isCurrentSpace })
        let newCurrent = spaces.first(where: { $0.isCurrentSpace })
        if let oldSpace = oldCurrent, let newSpace = newCurrent, oldSpace.spaceID != newSpace.spaceID {
            previousSpaceID = oldSpace.spaceID
        }

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

        // Re-measure the available room when the environment may have
        // changed, so the icon grows back if space freed up.
        if trigger.resetsFittedSize {
            fittedSize = nil
            budget = nil
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
