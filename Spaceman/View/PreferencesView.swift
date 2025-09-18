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
    @AppStorage("schema") private var keySet = KeySet.toprow
    @AppStorage("withShift") private var withShift = false
    @AppStorage("withControl") private var withControl = false
    @AppStorage("withOption") private var withOption = false
    @AppStorage("withCommand") private var withCommand = false

    @StateObject private var prefsVM = PreferencesViewModel()
    
    // MARK: - Main Body
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                closeButton
                appInfo
            }
            .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 70, alignment: .center)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                generalPane
                Divider()
                switchingPane
            }
            Divider()
            spacesPane
        }
        .padding(.bottom, 20)
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
            // The Space names are always shown in the menu, therefore: allow editing independent of icon style
            spaceNameListEditor
            
            Toggle("Only show active spaces", isOn: $hideInactiveSpaces)
                .disabled(displayStyle == .rects)
            Toggle("Restart space numbering by display", isOn: $restartNumberingByDesktop)
        }
        .padding()
        .onChange(of: hideInactiveSpaces) { _ in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
    }
    
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
        Picker(selection: $layoutMode, label: Text("Layout")) {
            Text("Compact").tag(LayoutMode.compact)
            Text("Medium").tag(LayoutMode.medium)
            Text("Large").tag(LayoutMode.large)
            Text("X Large").tag(LayoutMode.extraLarge)
        }
        .pickerStyle(.segmented)
        .onChange(of: layoutMode) { val in
            layoutMode = val
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
        }
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
    
    // MARK: - Space Name Editor (select via drop-down)
    private var spaceNameEditor: some View {
        HStack {
            Picker(selection: $prefsVM.selectedSpace, label: Text("Space")) {
                ForEach(0..<prefsVM.sortedSpaceNamesDict.count, id: \.self) { index in
                    Text(String(prefsVM.sortedSpaceNamesDict[index].value.spaceByDesktopID))
                }
            }
            .onChange(of: prefsVM.selectedSpace) { val in
                if (prefsVM.sortedSpaceNamesDict.count > val) {
                    prefsVM.spaceName = prefsVM.sortedSpaceNamesDict[val].value.spaceName
                } else {
                    prefsVM.spaceName = "-"
                }
            }
            
            TextField(
                "Name (max 4 char.)",
                text: Binding(
                    get: {prefsVM.spaceName},
                    set: {
                        // Store full name; may be truncated in some icon modes
                        prefsVM.spaceName = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        updateName()
                    }
                    
                )
            )
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
                    HStack(spacing: 8) {
                        Text("Space \(entry.value.spaceByDesktopID):")
                            .frame(width: 120, alignment: .trailing)
                            .foregroundColor(.secondary)
                        TextField(
                            //visibleSpacesMode == .all ? "Name (4 shown in All)" : (visibleSpacesMode == .neighbors ? "Name (6 shown in Neighbors)" : "Name"),
                            "Name",
                            text: Binding(
                                get: { entry.value.spaceName },
                                set: { newVal in
                                    let trimmed = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                                    // Future method calls for when other developer's code is merged:
                                    // prefsVM.updateSpace(for: entry.key, to: trimmed)
                                    // prefsVM.persistChanges(for: entry.key)

                                    // Temporary implementation using current data structure:
                                    let spaceNum = entry.value.spaceNum
                                    let spaceByDesktopID = entry.value.spaceByDesktopID
                                    prefsVM.spaceNamesDict[entry.key] = SpaceNameInfo(
                                        spaceNum: spaceNum,
                                        spaceName: trimmed.isEmpty ? "-" : trimmed,
                                        spaceByDesktopID: spaceByDesktopID
                                    )
                                    // Manual persistence
                                    UserDefaults.standard.set(try? PropertyListEncoder().encode(prefsVM.spaceNamesDict), forKey: "spaceNames")
                                    // Refresh sorted list
                                    prefsVM.loadData()
                                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
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
