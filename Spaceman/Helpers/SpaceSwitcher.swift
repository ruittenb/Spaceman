//
//  SpaceSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 28/08/2024.
//

import Foundation
import SwiftUI

class SpaceSwitcher {
    @AppStorage("enableSwitchingSpaces") private var enableSwitchingSpaces = true
    private var shortcutHelper: ShortcutHelper!
    private var spacesSnapshot: [Space] = []
    private let arrowLeftKeyCode = 123
    private let arrowRightKeyCode = 124

    init() {
        shortcutHelper = ShortcutHelper()
        // Only check AX trust if switching is enabled
        if enableSwitchingSpaces {
            // Check if the process has Accessibility permission, and make sure it has been added to the list
            AXIsProcessTrusted()
        }
    }

    public func updateSpacesSnapshot(_ spaces: [Space]) {
        spacesSnapshot = spaces
    }

    public func switchToSpace(spaceNumber: Int, spaceID: String? = nil, onError: () -> Void) {
        guard enableSwitchingSpaces else { return }
        if shortcutHelper.currentKeySet == .arrows {
            guard performArrowSwitch(toSpaceID: spaceID, fallbackSpaceNumber: spaceNumber) else {
                onError()
                return
            }
            return
        }
        let keyCode = shortcutHelper.getKeyCode(spaceNumber: spaceNumber)
        if keyCode < 0 {
            return onError()
        }
        let modifiers = shortcutHelper.getModifiers()
        let appleScript = makeAppleScript(keyCode: keyCode, modifiers: modifiers)
        var error: NSDictionary?
        DispatchQueue.global(qos: .background).async {
            if let scriptObject = NSAppleScript(source: appleScript) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    guard
                        let errorNumber = error?[NSAppleScript.errorNumber] as? Int,
                        let errorBriefMessage = error?[NSAppleScript.errorBriefMessage] as? String
                    else {
                        return
                    }
                    let settingsName = self.systemSettingsName()
                    // -1002: Error: Spaceman is not allowed to send keystrokes. (needs Accessibility permission)
                    // -1743: Error: Not authorized to send Apple events to System Events. (needs Automation permission)
                    let normalizedCode = abs(errorNumber)
                    let permissionType: String
                    switch normalizedCode {
                    case 1002:
                        permissionType = "Accessibility"
                    case 1743:
                        permissionType = "Automation"
                    default:
                        permissionType = "Automation"
                    }
                    self.alert(
                        msg: "Error: \(errorBriefMessage)\n\nPlease grant \(permissionType) permissions to Spaceman in \(settingsName) → Privacy and Security.",
                        permissionTypeName: permissionType)
                }
            }
        }
    }
    
    public func switchUsingLocation(iconWidths: [IconWidth], horizontal: CGFloat, onError: () -> Void) {
        guard let match = iconWidths.first(where: { horizontal >= $0.left && horizontal < $0.right }) else {
            onError()
            return
        }
        guard match.index != 0 else {
            onError()
            return
        }
        switchToSpace(spaceNumber: match.index, spaceID: match.spaceID, onError: onError)
    }
    
    private func systemSettingsName() -> String {
        if #available(macOS 13.0, *) {
            return "System Settings"
        } else {
            return "System Preferences"
        }
    }
    
    private func alert(msg: String, permissionTypeName: String) {
        DispatchQueue.main.async {
            let alert = NSAlert.init()
            alert.messageText = "Spaceman"
            alert.informativeText = "\(msg)"
            alert.addButton(withTitle: "Dismiss")
            if permissionTypeName != "" {
                let settingsName = self.systemSettingsName()
                alert.addButton(withTitle: "\(settingsName)...")
            }
            let response = alert.runModal()
            if (response == .alertSecondButtonReturn) {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["x-apple.systempreferences:com.apple.preference.security?Privacy_\(permissionTypeName)"]
                try? task.run()
            }
        }
    }
}

extension SpaceSwitcher {
    private func performArrowSwitch(toSpaceID spaceID: String?, fallbackSpaceNumber: Int) -> Bool {
        let targetIndex = spacesSnapshot.firstIndex { candidate in
            if let spaceID, !spaceID.isEmpty {
                return candidate.spaceID == spaceID
            }
            return candidate.spaceNumber == fallbackSpaceNumber
        }
        guard let currentIndex = spacesSnapshot.firstIndex(where: { $0.isCurrentSpace }),
              let resolvedTargetIndex = targetIndex
        else {
            return false
        }
        let delta = resolvedTargetIndex - currentIndex
        guard delta != 0 else { return true }

        let steps = abs(delta)
        let keyCode = delta > 0 ? arrowRightKeyCode : arrowLeftKeyCode
        let modifiers = shortcutHelper.getModifiers()

        for _ in 0..<steps {
            let appleScript = makeAppleScript(keyCode: keyCode, modifiers: modifiers)
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: appleScript) {
                scriptObject.executeAndReturnError(&error)
                if error != nil {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }

    private func makeAppleScript(keyCode: Int, modifiers: String) -> String {
        if modifiers.isEmpty {
            return "tell application \"System Events\" to key code \(keyCode)"
        }
        return "tell application \"System Events\" to key code \(keyCode) using {\(modifiers)}"
    }
}
