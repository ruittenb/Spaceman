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
    private let subItemIndent: CGFloat = 20

    @AppStorage("displayStyle") private var displayStyle = IconText.numbers
    @AppStorage("decorationActive") private var decorationActive = IconStyle.filledRounded
    @AppStorage("decorationInactive") private var decorationInactive = IconStyle.borderedRounded
    @AppStorage("useVariableWidth") private var useVariableWidth = false
    @AppStorage("fontDesign") private var fontDesign = FontDesign.monospaced
    @AppStorage("autoRefreshSpaces") private var autoRefreshSpaces = false
    @AppStorage("autoShrink") private var autoShrink = true
    @AppStorage("iconSize") private var iconSize = IconSize.medium
    @AppStorage("rowLayout") private var rowLayout = RowLayout.singleRow
    @AppStorage("showMissionControl") private var showMissionControl = false
    @AppStorage("showNavArrows") private var showNavArrows = false
    @AppStorage("navigateAnywhere") private var navigateAnywhere = false
    @AppStorage("visibleSpacesMode") private var visibleSpacesModeRaw: Int = VisibleSpacesMode.all.rawValue
    @AppStorage("neighborRadius") private var neighborRadius = 1
    @AppStorage("showFullscreenSpaces") private var showFullscreenSpaces = true
    @AppStorage("restartNumberingByDisplay") private var restartNumberingByDisplay = false
    @AppStorage("horizontalDirection") private var horizontalDirection = HorizontalDirection.defaultOrder
    @AppStorage("verticalDirection") private var verticalDirection = VerticalDirection.bottomGoesFirst

    private var visibleSpacesMode: VisibleSpacesMode {
        get { VisibleSpacesMode(rawValue: visibleSpacesModeRaw) ?? .all }
        set { visibleSpacesModeRaw = newValue.rawValue }
    }

    @StateObject private var prefsVM = PreferencesViewModel()
    @State private var selectedTab = 0
    @FocusState private var tabPickerFocused: Bool
    @State private var showDisplaysHelp = false
    @State private var showSwitchingHelp = false

    // MARK: - Main Body
    var body: some View {
        VStack(spacing: 0) {
            appInfo
            Divider()
            preferencePanes
        }
        .onAppear(perform: prefsVM.loadData)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActiveSpacesChanged"))) { _ in
            prefsVM.loadData()
        }
    }

    // MARK: - App Info
    private var appInfo: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
            Text("Version \(Constants.AppInfo.appVersion ?? "?")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Button {
                    NSWorkspace.shared.open(Constants.AppInfo.repo)
                } label: {
                    Text("Documentation").font(.callout)
                }
                .buttonStyle(LinkButtonStyle())
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                Text("·").font(.callout).foregroundColor(.secondary)
                Button {
                    NSWorkspace.shared.open(Constants.AppInfo.website)
                } label: {
                    Text("Website").font(.callout)
                }
                .buttonStyle(LinkButtonStyle())
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.vertical, 2)
    }

    // MARK: - Preference Panes
    private var preferencePanes: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("General").help("⌘1").tag(0)
                Text("Appearance").help("⌘2").tag(1)
                Text("Spaces").help("⌘3").tag(2)
                Text("Displays").help("⌘4").tag(3)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .focused($tabPickerFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    tabPickerFocused = true
                }
            }
            .padding(10)
            .background(
                Group {
                    Button("") { selectedTab = 0 }
                        .keyboardShortcut("1", modifiers: .command)
                        .hidden()
                    Button("") { selectedTab = 1 }
                        .keyboardShortcut("2", modifiers: .command)
                        .hidden()
                    Button("") { selectedTab = 2 }
                        .keyboardShortcut("3", modifiers: .command)
                        .hidden()
                    Button("") { selectedTab = 3 }
                        .keyboardShortcut("4", modifiers: .command)
                        .hidden()
                }
            )

            Divider()

            // Tab content
            Group {
                if selectedTab == 0 {
                    VStack(alignment: .leading, spacing: 0) {
                        generalPane
                        Divider()
                        menuPane
                        Divider()
                        backupRestorePane
                    }
                } else if selectedTab == 1 {
                    appearancePane
                } else if selectedTab == 2 {
                    spacesPane
                } else {
                    displaysPane
                }
            }
        }
        .padding(.bottom, 20)
        .onChange(of: selectedTab) { _ in
            NotificationCenter.default.post(
                name: NSNotification.Name("PreferencesTabChanged"), object: nil)
        }
    }

    // MARK: - General pane
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 12)
            LaunchAtLogin.Toggle { Text("Launch Spaceman at login") }
                .padding(.bottom, 8)
            Toggle("Refresh spaces in background", isOn: $autoRefreshSpaces)
                .padding(.bottom, 6)
            refreshShortcutRecorder
            quickRenameShortcutRecorder
            preferencesShortcutRecorder
        }
        .padding()
        .onChange(of: autoRefreshSpaces) { enabled in
            if enabled {
                prefsVM.startTimer()
            } else {
                prefsVM.pauseTimer()
            }
        }
    }

    // MARK: - Displays pane
    private var displaysPane: some View {
        let hasMultipleDisplays = NSScreen.screens.count > 1
        return VStack(alignment: .leading, spacing: 8) {
            Text("Displays")
                .font(.title2)
                .fontWeight(.semibold)

            Toggle("Restart space numbering by display", isOn: $restartNumberingByDisplay)
                .disabled(!hasMultipleDisplays)
            HStack(alignment: .top) {
                Text("When displays are side by side")
                    .foregroundColor(hasMultipleDisplays ? .primary : .secondary)
                    .frame(width: 200, alignment: .leading)
                Picker("", selection: $horizontalDirection) {
                    Text("Use macOS order").tag(HorizontalDirection.defaultOrder)
                    Text("Reverse macOS order").tag(HorizontalDirection.reverseOrder)
                }
                .pickerStyle(.radioGroup)
                .disabled(!hasMultipleDisplays)
                .fixedSize()
            }

            HStack(alignment: .top) {
                Text("When displays are stacked")
                    .foregroundColor(hasMultipleDisplays ? .primary : .secondary)
                    .frame(width: 200, alignment: .leading)
                Picker("", selection: $verticalDirection) {
                    Text("Use macOS order").tag(VerticalDirection.defaultOrder)
                    Text("Show top display first").tag(VerticalDirection.topGoesFirst)
                    Text("Show bottom display first").tag(VerticalDirection.bottomGoesFirst)
                }
                .pickerStyle(.radioGroup)
                .disabled(!hasMultipleDisplays)
                .fixedSize()
            }

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
                    Text("""
                        If the display order seems erratic, please pay close \
                        attention to the horizontal alignment in \
                        \(systemSettingsName()) → Displays → Arrange.
                        """)
                    .padding()
                    .frame(width: 240)
                }
            }
            .padding(.top)
        }
        .padding()
        .onChange(of: restartNumberingByDisplay) { _ in
            postRefreshNotification()
        }
        .onChange(of: horizontalDirection) { _ in
            postRefreshNotification()
        }
        .onChange(of: verticalDirection) { _ in
            postRefreshNotification()
        }
    }

    // MARK: - Backup / Restore pane
    private var backupRestorePane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup")
                .font(.title2)
                .fontWeight(.semibold)
            HStack(spacing: 12) {
                Button("Backup Preferences") {
                    prefsVM.backupPreferences()
                }
                if let message = prefsVM.backupStatusMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(prefsVM.backupStatusIsError ? .red : .green)
                }
            }
            HStack(spacing: 12) {
                Button("Restore Preferences") {
                    prefsVM.restorePreferences()
                }
                .disabled(prefsVM.lastBackupDate == nil)
                if let message = prefsVM.restoreStatusMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(prefsVM.restoreStatusIsError ? .red : .green)
                } else if let date = prefsVM.lastBackupDate {
                    Text("Last backup: \(date, style: .date) \(date, style: .time)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No backup found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom)
        }
        .padding()
    }

    // MARK: - Spaces pane
    private var spacesPane: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Spaces")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                if prefsVM.spaceNamesDict.values.contains(where: { $0.colorHex != nil }) {
                    HStack(spacing: 4) {
                        Text("Clear all colors")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Button {
                            prefsVM.removeAllColors()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NotificationCenter.default.post(
                                    name: ButtonPressedName,
                                    object: nil)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            // The Space names are always shown in the menu, therefore:
            // allow editing even if icon style does not include names
            spaceNameListEditor

            Spacer()
                .frame(height: 12)

            switchingOptions
        }
        .padding()
    }

    // MARK: - Appearance pane
    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.title2)
                .fontWeight(.semibold)
            iconSizePicker
            iconWidthPicker
            spacesStylePicker
            fontDesignPicker
            activeIconStylePicker
            inactiveIconStylePicker
            if displayStyle == .noText && decorationActive.isNoDecoration && decorationInactive.isNoDecoration {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Icons will be invisible with these settings.")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else if decorationActive == decorationInactive {
                Text("Inactive icons will be dimmed for visual distinctness.")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Divider()
                .padding(.vertical, 2)
            rowLayoutPicker
            spacesShownPicker
            Toggle("Show fullscreen spaces", isOn: $showFullscreenSpaces)
            Toggle("Show Mission Control button", isOn: $showMissionControl)
            Toggle("Show navigation arrows", isOn: $showNavArrows)
            Toggle("Auto-shrink when there is shortage of space", isOn: $autoShrink)
        }
        .padding()
        .onChange(of: autoShrink) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: visibleSpacesModeRaw) { _ in
            postRefreshNotification()
        }
        .onChange(of: showFullscreenSpaces) { _ in
            postRefreshNotification()
        }
        .onChange(of: showMissionControl) { _ in
            postRefreshNotification()
        }
        .onChange(of: showNavArrows) { _ in
            postRefreshNotification()
        }
    }

    // MARK: - Menu pane
    @AppStorage("spaceDisplayMode") private var spaceDisplayMode = SpaceDisplayMode.list
    @AppStorage("gridColumns") private var gridColumns: Int = 3

    private var menuPane: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Menu")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 12)
            HStack {
                Text("Display spaces in menu as")
                Spacer()
                Picker("", selection: $spaceDisplayMode) {
                    Text("List").tag(SpaceDisplayMode.list)
                    Text("Grid").tag(SpaceDisplayMode.grid)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(.bottom, 8)
            HStack {
                Text("Nr. of columns in grid")
                    .foregroundColor(spaceDisplayMode == .grid ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Slider(value: Binding(
                    get: { Double(gridColumns) },
                    set: { gridColumns = max(1, Int($0)) }
                ), in: 1...Double(max(2, prefsVM.spaceNamesDict.count)), step: 1)
                    .disabled(spaceDisplayMode != .grid)
                    .padding(.horizontal, 10)
                Text("\(gridColumns)")
                    .monospacedDigit()
                    .foregroundColor(spaceDisplayMode == .grid ? .primary : .secondary)
                    .frame(width: 10, alignment: .trailing)
            }
            .padding(.leading, subItemIndent)
        }
        .padding()
    }

    // MARK: - Switching options (shown at the bottom of Spaces tab)
    private var switchingOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $navigateAnywhere) {
                Text("Allow switching to fullscreen spaces using multiple steps")
                    .fixedSize(horizontal: false, vertical: true)
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
                    Text("""
                        Spaceman reads the Mission Control keyboard shortcuts directly \
                        from your system settings. To change them, use this button.
                        """)
                    .padding()
                    .frame(width: 240)
                }
            }
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

    // MARK: - Quick Rename Shortcut Recorder
    private var quickRenameShortcutRecorder: some View {
        HStack {
            Text("Shortcut to rename current space")
            Spacer()
            KeyboardShortcuts.Recorder(for: .quickRename)
        }
    }

    // MARK: - Icon Size Picker
    private var iconSizePicker: some View {
        let availableSizes = rowLayout.isTwoRows
            ? Array(Constants.sizesTwoRows.keys).sorted { $0.rawValue < $1.rawValue }
            : Array(IconSize.allCases)
        return HStack(spacing: 12) {
            Text("Icon size")
            Spacer()
            Picker("", selection: $iconSize) {
                ForEach(availableSizes, id: \.self) { mode in
                    Text(mode.menuLabel).tag(mode)
                }
            }
            .fixedSize()
        }
        .onChange(of: iconSize) { _ in
            postRefreshNotification()
        }
    }

    // MARK: - Row Layout Picker
    private var rowLayoutPicker: some View {
        HStack(spacing: 12) {
            Text("Rows")
                .fixedSize()
            Spacer(minLength: 8)
            HStack(spacing: 1) {
                ForEach(RowLayout.allCases, id: \.self) { layout in
                    let isSelected = rowLayout == layout
                    Button(layout.pickerLabel) {
                        rowLayout = layout
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(isSelected ? .white : .primary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .onChange(of: rowLayout) { newValue in
            if newValue.isTwoRows && Constants.sizesTwoRows[iconSize] == nil {
                switch iconSize {
                case .narrow, .compact:              iconSize = .compact
                case .medium:                        iconSize = .medium
                case .large, .extraLarge, .enormous: iconSize = .large
                }
            }
            postRefreshNotification()
        }
    }

    // MARK: - Style Pickers
    private var spacesStylePicker: some View {
        HStack(spacing: 12) {
            Text("Icon text")
            Spacer()
            Picker("", selection: $displayStyle) {
                Text("No text").tag(IconText.noText)
                Text("Numbers").tag(IconText.numbers)
                Text("Names").tag(IconText.names)
                Text("Numbers and names").tag(IconText.numbersAndNames)
            }
            .fixedSize()
        }
        .onChange(of: displayStyle) { _ in
            postRefreshNotification()
        }
    }

    private var fontDesignPicker: some View {
        HStack(spacing: 12) {
            Text("Font")
                .fixedSize()
                .foregroundColor(displayStyle != .noText ? .primary : .secondary)
                .padding(.leading, subItemIndent)
            Spacer(minLength: 8)
            Picker("", selection: $fontDesign) {
                ForEach(FontDesign.allCases, id: \.self) { design in
                    Text(design.menuLabel).tag(design)
                }
            }
            .fixedSize()
        }
        .disabled(displayStyle == .noText)
        .onChange(of: fontDesign) { _ in
            postRefreshNotification()
        }
    }

    // MARK: - IconStyle Pickers
    private var activeIconStylePicker: some View {
        HStack(spacing: 12) {
            Text("Active style")
            Spacer()
            Picker("", selection: $decorationActive) {
                ForEach(IconStyle.allCases, id: \.self) { decoration in
                    Text(decoration.menuLabel).tag(decoration)
                }
            }
            .fixedSize()
        }
        .onChange(of: decorationActive) { _ in
            postRefreshNotification()
        }
    }

    private var inactiveIconStylePicker: some View {
        HStack(spacing: 12) {
            Text("Inactive style")
            Spacer()
            Picker("", selection: $decorationInactive) {
                ForEach(IconStyle.allCases, id: \.self) { decoration in
                    Text(decoration.menuLabel).tag(decoration)
                }
            }
            .fixedSize()
        }
        .onChange(of: decorationInactive) { _ in
            postRefreshNotification()
        }
    }

    // MARK: - Icon Width Picker
    private var iconWidthPicker: some View {
        HStack(spacing: 12) {
            Text("Icon width")
                .padding(.leading, subItemIndent)
            Spacer()
            Picker("", selection: $useVariableWidth) {
                Text("Roughly equal").tag(false)
                Text("Variable").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .onChange(of: useVariableWidth) { _ in
            postRefreshNotification()
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
                    let spacePart: String = sbd.hasPrefix("F")
                        ? "Full Screen " + String(Int(sbd.dropFirst()) ?? 0)
                        : "Space \(sbd)"
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
                                    NotificationCenter.default.post(
                                        name: ButtonPressedName,
                                        object: nil)
                                }
                            )
                        )
                        .frame(alignment: .trailing)
                        .textFieldStyle(.roundedBorder)

                        // Color picker
                        ColorWellView(
                            selectedColor: Binding(
                                get: {
                                    // Read from live spaceNamesDict, not the snapshot
                                    if let currentInfo = prefsVM.spaceNamesDict[entry.key],
                                       let hexString = currentInfo.colorHex {
                                        return NSColor.fromHex(hexString)
                                    }
                                    return nil
                                },
                                set: { _ in }
                            ),
                            onColorChange: { newColor in
                                prefsVM.updateSpaceColor(for: entry.key, to: newColor)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    NotificationCenter.default.post(
                                        name: ButtonPressedName,
                                        object: nil)
                                }
                            }
                        )
                        .frame(width: 35, height: 24)

                        // Clear color button (or invisible placeholder for alignment)
                        if prefsVM.spaceNamesDict[entry.key]?.colorHex != nil {
                            Button {
                                prefsVM.updateSpaceColor(for: entry.key, to: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    NotificationCenter.default.post(
                                        name: ButtonPressedName,
                                        object: nil)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Clear color")
                        } else {
                            // Invisible placeholder for alignment
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.clear)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Spaces shown picker
    private var spacesShownPicker: some View {
        return VStack(alignment: .leading) {
            HStack(spacing: 12) {
                Text("Spaces shown")
                    .fixedSize()
                    .layoutPriority(1)
                Spacer()
                HStack(spacing: 1) {
                    ForEach(VisibleSpacesMode.allCases, id: \.self) { mode in
                        let isSelected = visibleSpacesMode == mode
                        Button(mode.pickerLabel) {
                            visibleSpacesModeRaw = mode.rawValue
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(isSelected ? .white : .primary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Stepper(value: $neighborRadius, in: 1...3) {
                Text("Nearby range: ±\(neighborRadius)")
                    .foregroundColor(visibleSpacesMode == .neighbors ? .primary : .secondary)
                    .padding(.leading, subItemIndent)
            }
            .disabled(visibleSpacesMode != .neighbors)
            .onChange(of: neighborRadius) { _ in
                postRefreshNotification()
            }
        }
    }

}

// MARK: - Open Displays Settings
/// Opens the macOS Displays settings (macOS 11+).
func openDisplaysSettings() {
    openSettings(candidates: [
        "x-apple.systempreferences:com.apple.Displays-Settings.extension", // Ventura/Sequoia/Tahoe
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
        // Ventura+/Tahoe new-style Keyboard settings with Shortcuts anchor (can be finicky on some builds)
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
        PreferencesView()
    }
}
