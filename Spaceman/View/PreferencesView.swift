//
//  PreferencesView.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Cocoa
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct PreferencesView: View {

    weak var parentWindow: PreferencesWindow?

    @AppStorage("displayStyle") private var displayStyle = DisplayStyle.numbersAndRects
    @AppStorage("spaceNames") private var data = Data()
    @AppStorage("autoRefreshSpaces") private var autoRefreshSpaces = false
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.medium
    @AppStorage("visibleSpacesMode") private var visibleSpacesModeRaw: Int = VisibleSpacesMode.all.rawValue
    @AppStorage("neighborRadius") private var neighborRadius = 1
    @AppStorage("restartNumberingByDisplay") private var restartNumberingByDesktop = false
    @AppStorage("reverseDisplayOrder") private var reverseDisplayOrder = false
    @AppStorage("dualRowFillOrder") private var dualRowFillOrder = DualRowFillOrder.byColumn
    @AppStorage("verticalDirection") private var verticalDirection = VerticalDirection.bottomGoesFirst
    @AppStorage("schema") private var keySet = KeySet.toprow
    @AppStorage("withShift") private var withShift = false
    @AppStorage("withControl") private var withControl = false
    @AppStorage("withOption") private var withOption = false
    @AppStorage("withCommand") private var withCommand = false

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }

    @StateObject private var prefsVM = PreferencesViewModel()
    @State private var selectedTab = 0
    @State private var showDisplaysHelp = false
    @State private var showSwitchingHelp = false

    // MARK: - Main Body
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                closeButton
                appInfo
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 60)
            .offset(y: 1) // Looked like it was off center

            Divider()

            preferencePanes
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear(perform: prefsVM.loadData)
        .onChange(of: data) { _ in
            prefsVM.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActiveSpacesChanged"))) { _ in
            prefsVM.loadData()
        }
    }

    // MARK: - Close Button
    private var closeButton: some View {
        VStack {
            Spacer()
            HStack {
                if let parentWindow = parentWindow {
                    Button {
                        parentWindow.close()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .keyboardShortcut("w", modifiers: .command)
                    .help("Close window (⌘W)")
                    .padding(.leading, 12)
                }
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - App Info
    private var appInfo: some View {
        HStack(spacing: 8) {
            HStack {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading) {
                    Text("Spaceman").font(.headline)
                    Text("Version \(Constants.AppInfo.appVersion ?? "?")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading)

            Spacer()

            HStack {
                Button {
                    NSWorkspace.shared.open(Constants.AppInfo.repo)
                } label: {
                    Text("GitHub").font(.system(size: 12))
                }
                .buttonStyle(LinkButtonStyle())

                Button {
                    NSWorkspace.shared.open(Constants.AppInfo.website)
                } label: {
                    Text("Website").font(.system(size: 12))
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Preference Panes
    private var preferencePanes: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Spaces").tag(1)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            // Tab content
            Group {
                if selectedTab == 0 {
                    VStack(alignment: .leading, spacing: 0) {
                        generalPane
                        Divider()
                        displaysPane
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        spacesPane
                        Divider()
                        switchingPane
                    }
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - General pane
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
            LaunchAtLogin.Toggle(){Text("Launch Spaceman at login")}
            Toggle("Refresh spaces in background", isOn: $autoRefreshSpaces)
            refreshShortcutRecorder.disabled(autoRefreshSpaces)
            preferencesShortcutRecorder
            layoutSizePicker
            dualRowFillOrderPicker
        }
        .padding()
        .onChange(of: autoRefreshSpaces) { enabled in
            if enabled {
                prefsVM.startTimer()
                KeyboardShortcuts.disable(.refresh)
            }
            else {
                prefsVM.pauseTimer()
                KeyboardShortcuts.enable(.refresh)
            }
        }
        .onChange(of: dualRowFillOrder) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // MARK: - Displays pane
    private var displaysPane: some View {
        let hasMultipleDisplays = NSScreen.screens.count > 1
        return VStack(alignment: .leading, spacing: 8) {
            Text("Displays")
                .font(.title2)
                .fontWeight(.semibold)

            Toggle("Restart space numbering by display", isOn: $restartNumberingByDesktop)
                .disabled(!hasMultipleDisplays)

            Text("When displays are horizontally arranged")
                .foregroundColor(hasMultipleDisplays ? .primary : .secondary)
            Picker("", selection: $reverseDisplayOrder) {
                Text("Use macOS order").tag(false)
                Text("Reverse macOS order").tag(true)
            }
            .pickerStyle(.radioGroup)
            .disabled(!hasMultipleDisplays)
            .controlSize(.small)
            .padding(.leading, 12)
            .fixedSize()

            Text("When displays are vertically arranged")
                .foregroundColor(hasMultipleDisplays ? .primary : .secondary)
            Picker("", selection: $verticalDirection) {
                Text("Use mac OS order").tag(VerticalDirection.defaultOrder)
                Text("Show top display first").tag(VerticalDirection.topGoesFirst)
                Text("Show bottom display first").tag(VerticalDirection.bottomGoesFirst)
            }
            .pickerStyle(.radioGroup)
            .disabled(!hasMultipleDisplays)
            .controlSize(.small)
            .padding(.leading, 12)
            .fixedSize()

            HStack(spacing: 12) {
                Button {
                    openDisplaysSettings()
                } label: {
                    Text("Open \(systemSettingsName()) → Displays…")
                }
                Button {
                    showDisplaysHelp.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDisplaysHelp, arrowEdge: .trailing) {
                    Text("If the display order seems erratic, please pay close attention to the horizontal alignment in \(systemSettingsName()) → Displays → Arrange.")
                    .padding()
                    .frame(width: 240)
                }
            }
            .padding(.vertical)
        }
        .padding()
        .onChange(of: restartNumberingByDesktop) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: reverseDisplayOrder) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: verticalDirection) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // MARK: - Spaces pane
    private var spacesPane: some View {
        VStack(alignment: .leading) {
            Text("Spaces")
                .font(.title2)
                .fontWeight(.semibold)
            spacesStylePicker
            // The Space names are always shown in the menu, therefore: allow editing even if icon style does not include names
            spaceNameListEditor
                .padding(.bottom, 8)
            spacesShownPicker
        }
        .padding()
        .onChange(of: visibleSpacesModeRaw) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // MARK: - Refresh Shortcut Recorder
    private var refreshShortcutRecorder: some View {
        HStack {
            Text("Shortcut for manual refresh")
            Spacer()
            KeyboardShortcuts.Recorder(for: .refresh)
        }
    }

    // MARK: - Preferences Shortcut Recorder
    private var preferencesShortcutRecorder: some View {
        HStack {
            Text("Shortcut to open preferences window")
            Spacer()
            KeyboardShortcuts.Recorder(for: .preferences)
        }
    }

    // MARK: - Layout Size Picker
    private var layoutSizePicker: some View {
        Picker(selection: $layoutMode, label: Text("Layout")) {
            Text("Dual Row").tag(LayoutMode.dualRows)
            Text("Compact").tag(LayoutMode.compact)
            Text("Medium").tag(LayoutMode.medium)
            Text("Large").tag(LayoutMode.large)
            Text("X Large").tag(LayoutMode.extraLarge)
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .onChange(of: layoutMode) { val in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // MARK: - Dual Row Fill Order Picker
    private var dualRowFillOrderPicker: some View {
        HStack(spacing: 12) {
            Text("Dual Row fill order")
                .foregroundColor(layoutMode == .dualRows ? .primary : .secondary)
            Spacer()
            Picker("", selection: $dualRowFillOrder) {
                Text("Rows first").tag(DualRowFillOrder.byRow)
                Text("Columns first").tag(DualRowFillOrder.byColumn)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .disabled(layoutMode != .dualRows)
    }
    
    // MARK: - Style Picker
    private var spacesStylePicker: some View {
        Picker(selection: $displayStyle, label: Text("Icon style")) {
            Text("Rectangles").tag(DisplayStyle.rects)
            Text("Numbers").tag(DisplayStyle.numbers)
            Text("Rectangles with numbers").tag(DisplayStyle.numbersAndRects)
            Text("Names").tag(DisplayStyle.names)
            Text("Names with numbers").tag(DisplayStyle.numbersAndNames)
        }
        .onChange(of: displayStyle) { val in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // MARK: - Space Name List Editor
    private var spaceNameListEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if prefsVM.sortedSpaceNamesDict.count == 0 {
                Text("No spaces detected yet.")
                    .foregroundColor(.secondary)
            } else {
                // Show a text field per space entry (keyed to avoid index issues during updates)
                ForEach(prefsVM.sortedSpaceNamesDict, id: \.key) { entry in
                    let info = entry.value
                    let sbd = info.spaceByDesktopID
                    let displayIndex = info.currentDisplayIndex ?? 1
                    let spacePart: String = (sbd.hasPrefix("F") ? ("Full Screen "+String(Int(sbd.dropFirst()) ?? 0)) : "Space \(sbd)")
                    let hasMultipleDisplays = NSScreen.screens.count > 1
                    let label = hasMultipleDisplays ? "Display \(displayIndex)  \(spacePart)" : spacePart
                    let leftMargin = 40
                    let labelWidth = hasMultipleDisplays ? 140 : 80

                    HStack(spacing: 8) {
                        Text(label)
                            .frame(width: CGFloat(labelWidth), alignment: .leading)
                            .padding(.leading, CGFloat(leftMargin))
                            .foregroundColor(.secondary)
                        TextField(
                            "Name",
                            text: Binding(
                                get: { entry.value.spaceName },
                                set: { newVal in
                                    let trimmed = String(newVal.drop(while: { $0.isWhitespace }))
                                    prefsVM.updateSpace(for: entry.key, to: trimmed)
                                    prefsVM.persistChanges(for: entry.key)
                                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
                                }
                            )
                        )
                        .frame(alignment: .trailing)
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    // MARK: - Spaces shown picker
    private var spacesShownPicker: some View {
        return VStack(alignment: .leading) {
            Picker(selection: Binding(
                get: { visibleSpacesMode },
                set: { visibleSpacesModeRaw = $0.rawValue }
            ), label: Text("Spaces shown")) {
                Text("All spaces").tag(VisibleSpacesMode.all)
                Text("Nearby spaces").tag(VisibleSpacesMode.neighbors)
                Text("Current only").tag(VisibleSpacesMode.currentOnly)
            }
            .pickerStyle(.segmented)
            Stepper(value: $neighborRadius, in: 1...3) {
                Text("Nearby range: ±\(neighborRadius)")
                    .foregroundColor(visibleSpacesMode == .neighbors ? .primary : .secondary)
                    .padding(.leading, 40)
            }
            .disabled(visibleSpacesMode != .neighbors)
            .onChange(of: neighborRadius) { _ in
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
            }
        }
    }

    // MARK: - Switching pane
    private var switchingPane: some View {
        // Switching Pane
        VStack(alignment: .leading, spacing: 10) {
            Text("Switching Spaces")
                .font(.title2)
                .fontWeight(.semibold)
            HStack(alignment: .firstTextBaseline) {
                Text("Shortcut keys")
                    .frame(width: 130, alignment: .leading)
                Picker("Shortcut keys", selection: $keySet) {
                    Text("number keys on top row").tag(KeySet.toprow).padding(.bottom, 2)
                    Text("numeric keypad").tag(KeySet.numpad)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding(.bottom, 6)
            HStack(alignment: .top) {
                Text("With modifiers")
                    .frame(width: 130, alignment: .leading)
                VStack(alignment: .leading) {
                    Toggle("Shift ⇧", isOn: $withShift)
                    Toggle("Control ⌃", isOn: $withControl)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Toggle("Option ⌥", isOn: $withOption)
                    Toggle("Command ⌘", isOn: $withCommand)
                }
                Spacer()
            }
            .padding(.bottom, 6)
            HStack(spacing: 8) {
                Button {
                    openMissionControlShortcuts()
                } label: {
                    Text("Open \(systemSettingsName()) → Mission Control Shortcuts…")
                }
                Button {
                    showSwitchingHelp.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSwitchingHelp, arrowEdge: .trailing) {
                    Text("For switching between spaces to work, these settings must match the keyboard shortcuts assigned for Mission Control.")
                    .padding()
                    .frame(width: 240)
                }
            }
        }
        .padding()
        .onChange(of: keySet) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: [withShift, withControl, withCommand, withOption]) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }
}

// MARK: - Open Displays Settings
/// Opens the macOS Displays settings (macOS 11+).
func openDisplaysSettings() {
    openSettings(candidates: [
        "x-apple.systempreferences:com.apple.Displays-Settings.extension", // Ventura/Sequoia
        "x-apple.systempreferences:com.apple.preference.displays",         // Big Sur/Monterey
        "/System/Library/PreferencePanes/Displays.prefPane"                // Fallback
    ])
}

// MARK: - Open Keyboard Shortcuts Settings
/// Opens the Mission Control Shortcuts settings (best-effort, macOS 11+).
/// Tries Keyboard > Shortcuts first, then Ventura-style Keyboard settings,
/// then the old Mission Control pane, then prefPane file fallbacks.
func openMissionControlShortcuts() {
    openSettings(candidates: [
        // Works broadly (Monterey/Ventura/Sonoma/Sequoia): Keyboard > Shortcuts
        "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts",
        // Ventura+ new-style Keyboard settings with Shortcuts anchor (can be finicky on some builds)
        "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts",
        // Older direct Mission Control pane (not the shortcuts list, but relevant)
        "x-apple.systempreferences:com.apple.preference.expose",
        // File-path fallbacks
        "/System/Library/PreferencePanes/Keyboard.prefPane",
        "/System/Library/PreferencePanes/Expose.prefPane"
    ])
}

// MARK: - Open System Settings
/// Tries modern URL, then legacy URL, then the prefPane path — all via /usr/bin/open.
/// Intentionally ignores failures; best-effort launch only.
func openSettings(candidates: [String]) {
    for target in candidates {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = [target]
        do {
            try proc.run()
            break
        } catch {
            // Try the next candidate
            continue
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(parentWindow: nil)
    }
}
