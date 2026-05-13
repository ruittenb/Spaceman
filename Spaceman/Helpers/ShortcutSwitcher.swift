//
//  ShortcutSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-11.
//  Co-author: Claude Code
//
//  Handles all shortcut-based (AppleScript) space switching:
//  direct desktop shortcuts, arrow navigation, and chaining.

import Foundation
import SwiftUI

class ShortcutSwitcher {
    private let shortcutHelper = ShortcutHelper()
    private var chainObserver: NSObjectProtocol?
    private var chainTimeout: DispatchWorkItem?

    init() {
        AXIsProcessTrusted()
    }

    // MARK: - Query methods (used by strategizer and menu building)

    func reloadShortcuts() {
        shortcutHelper.reload()
    }

    /// Shortcut for a desktop number, for menu key equivalent display.
    func shortcut(forDesktop desktop: Int) -> SpaceShortcut? {
        shortcutHelper.shortcut(forDesktop: desktop)
    }

    /// Whether Move Left/Right shortcuts are configured in Mission Control.
    var hasArrowShortcuts: Bool {
        shortcutHelper.moveLeftShortcut != nil
            && shortcutHelper.moveRightShortcut != nil
    }

    /// Switch map filtered to only include desktops with enabled shortcuts.
    func buildEnabledSwitchMap(for spaces: [Space]) -> [String: Int] {
        Space.buildSwitchIndexMap(for: spaces).filter {
            shortcutHelper.getKeyCode(spaceNumber: $0.value) >= 0
        }
    }

    // MARK: - Execution

    /// Switch to a desktop by its switch index (1–16) via keyboard shortcut.
    func switchToSpace(_ switchIndex: Int, onError: () -> Void) {
        let keyCode = shortcutHelper.getKeyCode(spaceNumber: switchIndex)
        if keyCode < 0 {
            return onError()
        }
        let modifiers = shortcutHelper.getModifiers(spaceNumber: switchIndex)
        let appleScript = makeAppleScript(keyCode: keyCode, modifiers: modifiers)
        var error: NSDictionary?
        DispatchQueue.global(qos: .background).async {
            if let scriptObject = NSAppleScript(source: appleScript) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    guard let errorNumber = error?[NSAppleScript.errorNumber] as? Int
                    else { return }
                    guard let errorBriefMessage = error?[NSAppleScript.errorBriefMessage] as? String
                    else { return }
                    let settingsName = systemSettingsName()
                    let permissionType: String
                    switch abs(errorNumber) {
                    case 1002:
                        permissionType = "Accessibility"
                    case 1743:
                        permissionType = "Automation"
                    default:
                        permissionType = "Automation"
                    }
                    let msg = String(localized: """
                        Error: \(errorBriefMessage)

                        Please grant \(permissionType) permissions \
                        to Spaceman in \(settingsName) → Privacy and Security.
                        """)
                    self.alert(
                        msg: msg,
                        permissionTypeName: permissionType)
                }
            }
        }
    }

    /// Switch one space left or right via arrow shortcut.
    func switchRelative(goRight: Bool) {
        if goRight {
            let sc = shortcutHelper.moveRightShortcut
            sendKeyCode(
                sc?.keyCode ?? 124,
                modifiers: sc?.modifiers ?? "control down")
        } else {
            let sc = shortcutHelper.moveLeftShortcut
            sendKeyCode(
                sc?.keyCode ?? 123,
                modifiers: sc?.modifiers ?? "control down")
        }
    }

    /// Chain arrow keypresses from the current position.
    func chain(
        steps: Int, goRight: Bool,
        onError: @escaping () -> Void
    ) {
        executeChain(
            stepsRemaining: steps, goRight: goRight,
            onError: onError)
    }

    /// Jump to an anchor space, then chain remaining arrows.
    func jumpThenChain(
        anchor: Int, steps: Int, goRight: Bool,
        onError: @escaping () -> Void
    ) {
        switchToSpace(anchor, onError: onError)
        waitForSpaceChange {
            self.executeChain(
                stepsRemaining: steps, goRight: goRight,
                onError: onError)
        } onTimeout: {
            onError()
        }
    }

    /// Wait for a space change notification, then chain arrows.
    /// Used when the initial jump was performed by another mechanism
    /// (e.g. gesture) and only the chain part needs shortcut arrows.
    func waitThenChain(
        steps: Int, goRight: Bool,
        onError: @escaping () -> Void
    ) {
        waitForSpaceChange {
            self.executeChain(
                stepsRemaining: steps, goRight: goRight,
                onError: onError)
        } onTimeout: {
            onError()
        }
    }

    func cancelChain() {
        chainTimeout?.cancel()
        chainTimeout = nil
        removeChainObserver()
    }

    func triggerMissionControl() {
        let appleScript = "tell application \"Mission Control\" to launch"
        DispatchQueue.global(qos: .background).async {
            if let scriptObject = NSAppleScript(source: appleScript) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
            }
        }
    }

    // MARK: - Private

    private func executeChain(
        stepsRemaining: Int, goRight: Bool,
        onError: @escaping () -> Void
    ) {
        guard stepsRemaining > 0 else { return }
        switchRelative(goRight: goRight)
        if stepsRemaining == 1 { return }
        waitForSpaceChange {
            self.executeChain(
                stepsRemaining: stepsRemaining - 1,
                goRight: goRight, onError: onError)
        } onTimeout: {
            onError()
        }
    }

    private func waitForSpaceChange(
        onComplete: @escaping () -> Void,
        onTimeout: @escaping () -> Void
    ) {
        let timeout = DispatchWorkItem { [weak self] in
            self?.cancelChain()
            DispatchQueue.main.async { onTimeout() }
        }
        chainTimeout = timeout
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 2.0, execute: timeout)

        chainObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            timeout.cancel()
            self?.removeChainObserver()
            onComplete()
        }
    }

    private func removeChainObserver() {
        if let observer = chainObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            chainObserver = nil
        }
    }

    private func sendKeyCode(_ keyCode: Int, modifiers: String) {
        let appleScript = "tell application \"System Events\" "
            + "to key code \(keyCode) using {\(modifiers)}"
        DispatchQueue.global(qos: .background).async {
            if let scriptObject = NSAppleScript(source: appleScript) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
            }
        }
    }

    private func makeAppleScript(keyCode: Int, modifiers: String) -> String {
        if modifiers.isEmpty {
            return "tell application \"System Events\" to key code \(keyCode)"
        }
        return "tell application \"System Events\" "
            + "to key code \(keyCode) using {\(modifiers)}"
    }

    private func alert(msg: String, permissionTypeName: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Spaceman"
            alert.informativeText = "\(msg)"
            alert.addButton(withTitle: String(localized: "Dismiss"))
            if permissionTypeName != "" {
                let settingsName = systemSettingsName()
                alert.addButton(withTitle: "\(settingsName)…")
            }
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                let url = "x-apple.systempreferences:"
                    + "com.apple.preference.security?"
                    + "Privacy_\(permissionTypeName)"
                task.arguments = [url]
                try? task.run()
            }
        }
    }
}
