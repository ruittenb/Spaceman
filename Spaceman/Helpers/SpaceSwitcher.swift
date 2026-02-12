//
//  SpaceSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 28/08/2024.
//

import Foundation
import SwiftUI

class SpaceSwitcher {
    private let shortcutHelper = ShortcutHelper()

    init() {
        // Check if the process has Accessibility permission, and make sure it has been added to the list
        AXIsProcessTrusted()
    }

    public func switchToSpace(spaceNumber: Int, onError: () -> Void) {
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
                    let msg = "Error: \(errorBriefMessage)\n\n"
                        + "Please grant \(permissionType) permissions "
                        + "to Spaceman in \(settingsName) → Privacy and Security."
                    self.alert(
                        msg: msg,
                        permissionTypeName: permissionType)
                }
            }
        }
    }

    public func switchUsingLocation(iconWidths: [IconWidth], point: CGPoint, onError: () -> Void) {
        var index: Int = 0
        for i in 0 ..< iconWidths.count {
            let hitX = point.x >= iconWidths[i].left && point.x < iconWidths[i].right
            let hasY = iconWidths[i].top != 0 || iconWidths[i].bottom != 0
            let hitY = hasY ? (point.y >= iconWidths[i].top && point.y < iconWidths[i].bottom) : true
            if hitX && hitY {
                index = iconWidths[i].index
                break
            }
        }
        switchToSpace(spaceNumber: index, onError: onError)
    }

    private func alert(msg: String, permissionTypeName: String) {
        DispatchQueue.main.async {
            let alert = NSAlert.init()
            alert.messageText = "Spaceman"
            alert.informativeText = "\(msg)"
            alert.addButton(withTitle: "Dismiss")
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
