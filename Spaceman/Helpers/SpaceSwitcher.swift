//
//  SpaceSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-08-28.
//

import Foundation
import SwiftUI

class SpaceSwitcher {
    private let shortcutHelper = ShortcutHelper()
    private var chainObserver: NSObjectProtocol?
    private var chainTimeout: DispatchWorkItem?

    init() {
        // Check if the process has Accessibility permission, and make sure it has been added to the list
        AXIsProcessTrusted()
    }

    public func switchToSpace(spaceNumber: Int, onError: () -> Void) {
        let keyCode = shortcutHelper.getKeyCode(spaceNumber: spaceNumber)
        if keyCode < 0 {
            return onError()
        }
        let modifiers = shortcutHelper.getModifiers(spaceNumber: spaceNumber)
        let appleScript = makeAppleScript(keyCode: keyCode, modifiers: modifiers)
        var error: NSDictionary?
        DispatchQueue.global(qos: .background).async {
            if let scriptObject = NSAppleScript(source: appleScript) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    guard let errorNumber = error?[NSAppleScript.errorNumber] as? Int else { return }
                    guard let errorBriefMessage = error?[NSAppleScript.errorBriefMessage] as? String else { return }
                    let settingsName = systemSettingsName()
                    let permissionType: String
                    switch abs(errorNumber) {
                    case 1002:
                        // -1002: Error: Spaceman is not allowed to send keystrokes.
                        // (needs Accessibility permission)
                        permissionType = "Accessibility"
                    case 1743:
                        // -1743: Error: Not authorized to send Apple events to System Events.
                        // (needs Automation permission)
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

    public func triggerMissionControl() {
        let sc = shortcutHelper.missionControlShortcut
        sendKeyCode(sc?.keyCode ?? 126, modifiers: sc?.modifiers ?? "control down")
    }

    public func switchToPreviousSpace() {
        let sc = shortcutHelper.moveLeftShortcut
        sendKeyCode(sc?.keyCode ?? 123, modifiers: sc?.modifiers ?? "control down")
    }

    public func switchToNextSpace() {
        let sc = shortcutHelper.moveRightShortcut
        sendKeyCode(sc?.keyCode ?? 124, modifiers: sc?.modifiers ?? "control down")
    }

    func sendFullscreenShortcut(_ shortcut: SpaceShortcut) {
        sendKeyCode(shortcut.keyCode, modifiers: shortcut.modifiers)
    }

    private func sendKeyCode(_ keyCode: Int, modifiers: String) {
        let appleScript = "tell application \"System Events\" to key code \(keyCode) using {\(modifiers)}"
        DispatchQueue.global(qos: .background).async {
            if let scriptObject = NSAppleScript(source: appleScript) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
            }
        }
    }

    public func switchUsingLocation(
        iconWidths: [IconWidth], point: CGPoint,
        spaces: [Space], navigateAnywhere: Bool,
        onError: @escaping () -> Void
    ) {
        cancelChain()
        var hitIndex: Int = 0
        var hitSpaceNumber: Int = 0
        for i in 0 ..< iconWidths.count {
            let hitX = point.x >= iconWidths[i].left && point.x < iconWidths[i].right
            let hasY = iconWidths[i].top != 0 || iconWidths[i].bottom != 0
            let hitY = hasY ? (point.y >= iconWidths[i].top && point.y < iconWidths[i].bottom) : true
            if hitX && hitY {
                hitIndex = iconWidths[i].index
                hitSpaceNumber = iconWidths[i].spaceNumber
                break
            }
        }
        if hitIndex == Space.missionControlIndex {
            triggerMissionControl()
            return
        } else if hitIndex == Space.previousSpaceIndex {
            switchToPreviousSpace()
            return
        } else if hitIndex == Space.nextSpaceIndex {
            switchToNextSpace()
            return
        } else if (hitIndex == Space.unswitchableIndex || hitIndex < 0) && navigateAnywhere {
            navigateByChaining(
                targetSpaceNumber: hitSpaceNumber, spaces: spaces, onError: onError)
        } else if hitIndex < 0 {
            // F1 fullscreen with chaining disabled: send minus key (for Apptivate etc.)
            if let sc = shortcutHelper.fullscreenShortcut {
                sendKeyCode(sc.keyCode, modifiers: sc.modifiers)
            } else {
                onError()
            }
        } else if hitIndex == Space.unswitchableIndex {
            onError()
        } else {
            switchToSpace(spaceNumber: hitIndex, onError: onError)
        }
    }

    // MARK: - Chained navigation

    /// Navigate to a space that has no direct keyboard shortcut by chaining arrow keypresses.
    /// Finds the nearest directly-switchable space to the target, jumps there, then chains
    /// the remaining arrows. If the current space is on the same display and closer, chains
    /// from current position instead.
    func navigateByChaining(
        targetSpaceNumber: Int, spaces: [Space], onError: @escaping () -> Void
    ) {
        guard let targetSpace = spaces.first(where: { $0.spaceNumber == targetSpaceNumber }),
              let currentSpace = spaces.first(where: { $0.isCurrentSpace }) else {
            onError()
            return
        }

        // Find nearest directly-switchable space to target on the target's display
        let switchMap = Space.buildSwitchIndexMap(for: spaces)
        let targetDisplaySpaces = spaces.filter { $0.displayID == targetSpace.displayID }
        let switchable = targetDisplaySpaces.filter {
            guard let idx = switchMap[$0.spaceID] else { return false }
            return idx >= 1 && idx <= Space.maxSwitchableDesktop
        }
        let anchor = switchable.min(by: {
            abs($0.spaceNumber - targetSpaceNumber) < abs($1.spaceNumber - targetSpaceNumber)
        })

        let arrowsFromAnchor = anchor.map { abs(targetSpaceNumber - $0.spaceNumber) } ?? Int.max
        let sameDisplay = targetSpace.displayID == currentSpace.displayID
        let arrowsFromCurrent = sameDisplay ? abs(targetSpaceNumber - currentSpace.spaceNumber) : Int.max

        // Compare: chaining from current needs arrowsFromCurrent waits;
        // jumping to anchor needs 1 wait (direct switch) + arrowsFromAnchor waits
        if arrowsFromCurrent <= arrowsFromAnchor + 1 {
            // Chain from current position (same display, and it's closer or equal)
            guard arrowsFromCurrent > 0 else { return }
            let goRight = targetSpaceNumber > currentSpace.spaceNumber
            executeChain(stepsRemaining: arrowsFromCurrent, goRight: goRight, onError: onError)
        } else if let anchor = anchor, let switchIndex = switchMap[anchor.spaceID] {
            // Jump to nearest switchable anchor, then chain remaining arrows
            let delta = targetSpaceNumber - anchor.spaceNumber
            if delta == 0 {
                switchToSpace(spaceNumber: switchIndex, onError: onError)
                return
            }
            switchToSpace(spaceNumber: switchIndex, onError: onError)
            waitForSpaceChange {
                self.executeChain(stepsRemaining: abs(delta), goRight: delta > 0, onError: onError)
            } onTimeout: {
                onError()
            }
        } else {
            onError()
        }
    }

    /// Execute a chain of arrow keypresses, waiting for each space change notification.
    private func executeChain(stepsRemaining: Int, goRight: Bool, onError: @escaping () -> Void) {
        guard stepsRemaining > 0 else { return }
        if goRight {
            switchToNextSpace()
        } else {
            switchToPreviousSpace()
        }
        if stepsRemaining == 1 { return }
        waitForSpaceChange {
            self.executeChain(stepsRemaining: stepsRemaining - 1, goRight: goRight, onError: onError)
        } onTimeout: {
            onError()
        }
    }

    /// Wait for `activeSpaceDidChangeNotification`, then call `onComplete`.
    /// If no notification arrives within 2 seconds, calls `onTimeout`.
    private func waitForSpaceChange(onComplete: @escaping () -> Void, onTimeout: @escaping () -> Void) {
        let timeout = DispatchWorkItem { [weak self] in
            self?.cancelChain()
            DispatchQueue.main.async { onTimeout() }
        }
        chainTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeout)

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

    public func cancelChain() {
        chainTimeout?.cancel()
        chainTimeout = nil
        removeChainObserver()
    }

    private func removeChainObserver() {
        if let observer = chainObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            chainObserver = nil
        }
    }

    private func alert(msg: String, permissionTypeName: String) {
        DispatchQueue.main.async {
            let alert = NSAlert.init()
            alert.messageText = "Spaceman"
            alert.informativeText = "\(msg)"
            alert.addButton(withTitle: String(localized: "Dismiss"))
            if permissionTypeName != "" {
                let settingsName = systemSettingsName()
                alert.addButton(withTitle: "\(settingsName)...")
            }
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                let url = "x-apple.systempreferences:"
                    + "com.apple.preference.security?Privacy_\(permissionTypeName)"
                task.arguments = [url]
                try? task.run()
            }
        }
    }

    private func makeAppleScript(keyCode: Int, modifiers: String) -> String {
        if modifiers.isEmpty {
            return "tell application \"System Events\" to key code \(keyCode)"
        }
        return "tell application \"System Events\" to key code \(keyCode) using {\(modifiers)}"
    }
}
