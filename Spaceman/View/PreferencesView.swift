//
//  ContentView.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct PreferencesView: View {
    
    weak var parentWindow: PreferencesWindow?
    
    @AppStorage("displayStyle") private var displayStyle = DisplayStyle.numbersAndRects
    @AppStorage("spaceNames") private var data = Data()
    @AppStorage("autoRefreshSpaces") private var autoRefreshSpaces = false
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.medium
    @AppStorage("hideInactiveSpaces") private var hideInactiveSpaces = false
    @AppStorage("restartNumberingByDesktop") private var restartNumberingByDesktop = false
    // Display arrangement preferences (UI only)
    @AppStorage("displaySortPriority") private var displaySortPriority = DisplaySortPriority.horizontal
    @AppStorage("displayHorizontalOrder") private var displayHorizontalOrder = HorizontalSortOrder.leftToRight
    @AppStorage("displayVerticalOrder") private var displayVerticalOrder = VerticalSortOrder.topToBottom
    @AppStorage("schema") private var keySet = KeySet.toprow
    @AppStorage("withShift") private var withShift = false
    @AppStorage("withControl") private var withControl = false
    @AppStorage("withOption") private var withOption = false
    @AppStorage("withCommand") private var withCommand = false
    // Dual row settings (UI only)
    @AppStorage("dualRows") private var dualRows = false
    @AppStorage("dualRowsGap") private var dualRowsGap: Int = 1

    @StateObject private var prefsVM = PreferencesViewModel()
    
    // MARK: - Main Body
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                closeButton
                appInfo
            }
            .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 90, alignment: .center)
            .offset(y: 1) // Looked like it was off center
            
            Divider()
                        
            preferencePanes
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: prefsVM.loadData)
        .onChange(of: data) { _ in
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
        VStack(alignment: .leading, spacing: 0) {
            
            generalPane
            Divider()
            displaysPane
            Divider()
            spacesPane
            Divider()
            switchingPane
            .padding(.bottom, 40)
        }
    }

    // MARK: - General pane
    private var generalPane: some View {
        VStack(alignment: .leading) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
            LaunchAtLogin.Toggle(){Text("Launch Spaceman at login")}
            Toggle("Refresh spaces in background", isOn: $autoRefreshSpaces)
            shortcutRecorder.disabled(autoRefreshSpaces)
            layoutSizePicker
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
    }

    // MARK: - Spaces pane
    private var spacesPane: some View {
        VStack(alignment: .leading) {
            Text("Spaces")
                .font(.title2)
                .fontWeight(.semibold)
            spacesStylePicker
            spaceNameEditor
            
            Toggle("Only show active spaces", isOn: $hideInactiveSpaces)
                .disabled(displayStyle == .rects)
            Toggle("Restart space numbering by display", isOn: $restartNumberingByDesktop)
        }
        .padding()
        .onChange(of: hideInactiveSpaces) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: restartNumberingByDesktop) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // MARK: - Displays pane (UI only; disabled when only one display)
    private var displaysPane: some View {
        let hasMultipleDisplays = NSScreen.screens.count > 1
        return VStack(alignment: .leading, spacing: 12) {
            Text("Displays")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Text("Multi-display ordering")
                Spacer()
                Picker("", selection: $displaySortPriority) {
                    Text("Horizontal first").tag(DisplaySortPriority.horizontal)
                    Text("Vertical first").tag(DisplaySortPriority.vertical)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .fixedSize()
            }

            HStack(spacing: 12) {
                Text("Horizontal order")
                Spacer()
                Picker("", selection: $displayHorizontalOrder) {
                    Text("Left to right").tag(HorizontalSortOrder.leftToRight)
                    Text("Right to left").tag(HorizontalSortOrder.rightToLeft)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .fixedSize()
            }

            HStack(spacing: 12) {
                Text("Vertical order")
                Spacer()
                Picker("", selection: $displayVerticalOrder) {
                    Text("Top to bottom").tag(VerticalSortOrder.topToBottom)
                    Text("Bottom to top").tag(VerticalSortOrder.bottomToTop)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .fixedSize()
            }
        }
        .padding()
        .disabled(!hasMultipleDisplays)
        .onChange(of: displaySortPriority) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: displayHorizontalOrder) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        .onChange(of: displayVerticalOrder) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }

    // (Displays pane removed in this revert)
    
    // MARK: - Shortcut Recorder
    private var shortcutRecorder: some View {
        HStack {
            Text("Force refresh shortcut")
            Spacer()
            KeyboardShortcuts.Recorder(for: .refresh)
        }
    }
    
    // MARK: - Layout Size Picker
    private var layoutSizePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(selection: $layoutMode, label: Text("Layout size")) {
                Text("Compact").tag(LayoutMode.compact)
                Text("Medium").tag(LayoutMode.medium)
                Text("Large").tag(LayoutMode.large)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                // Dual row toggle (compact only)
                Toggle("Dual row", isOn: $dualRows)
                    .disabled(layoutMode != .compact)
                Spacer()
                // Line spacing picker (active only when Dual row is ON in compact)
                HStack(spacing: 6) {
                    Text("Line spacing")
                        .foregroundColor((layoutMode != .compact || !dualRows) ? .secondary : .primary)
                    Picker("", selection: $dualRowsGap) {
                        Text("0").tag(0)
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(maxWidth: 120)
                }
                .disabled(layoutMode != .compact || !dualRows)
            }
        }
        .onChange(of: layoutMode) { val in
            layoutMode = val
            if val != .compact { dualRows = false }
            // Do not trigger status bar refresh here for dual-row UI; only persist values.
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
        // Intentionally not posting ButtonPressed on dual-row changes to keep it UI-only for now
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
            if val == .rects {
                hideInactiveSpaces = false
            }
            displayStyle = val
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }
    
    // MARK: - Space Name Editor
    private var spaceNameEditor: some View {
        HStack(alignment: .center, spacing: 12) {
            Picker(selection: $prefsVM.selectedSpace, label: Text("Space")) {
                ForEach(0..<prefsVM.sortedSpaceNamesDict.count, id: \.self) { index in
                    let info = prefsVM.sortedSpaceNamesDict[index].value
                    let num = info.spaceNum
                    let sbd = info.spaceByDesktopID
                    let displayIndex = info.currentDisplayIndex ?? 1
                    let spacePart: String = (sbd.hasPrefix("F") ? ("Full Screen "+String(Int(sbd.dropFirst()) ?? 0)) : "Space \(sbd)")
                    Text("[\(num)] Display \(displayIndex): \(spacePart)")
                }
            }
            .layoutPriority(3)
            .onChange(of: prefsVM.selectedSpace) { val in
                if (prefsVM.sortedSpaceNamesDict.count > val) {
                    prefsVM.selectedKey = prefsVM.sortedSpaceNamesDict[val].key
                    prefsVM.spaceName = prefsVM.sortedSpaceNamesDict[val].value.spaceName
                } else {
                    prefsVM.spaceName = "-"
                    prefsVM.selectedKey = ""
                }
            }

            TextField(
                "Name (max 4 char.)",
                text: Binding(
                    get: { prefsVM.spaceName },
                    set: {
                        prefsVM.spaceName = $0.prefix(4).trimmingCharacters(in: .whitespacesAndNewlines)
                        updateName()
                    }
                )
            )
            .frame(width: 90)
        }
    }
    
    // MARK: - Update Name Method
    private func updateName() {
        prefsVM.updateSpace()
        self.data = try! PropertyListEncoder().encode(prefsVM.spaceNamesDict)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
    }
    
    // MARK: - Switching pane
    private var switchingPane: some View {
        // Switching Pane
        VStack(alignment: .leading) {
            Text("Switching Spaces")
                .font(.title2)
                .fontWeight(.semibold)
            Picker("Shortcut keys", selection: $keySet) {
                Text("number keys on top row").tag(KeySet.toprow)
                Text("numeric keypad").tag(KeySet.numpad)
            }
            .pickerStyle(.radioGroup)
            .disabled(false)
            HStack(alignment: .top) {
                Text("With modifiers")
                Spacer()
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(parentWindow: nil)
    }
}
