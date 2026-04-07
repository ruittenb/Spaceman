//
//  OpenPreferencesCommand.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2025-09-21.
//  Co-author: Claude Code
//

import Foundation
import Cocoa

class OpenPreferencesCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Use the same approach as RefreshCommand - post a notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "OpenPreferences"), object: nil)
        }
        return nil
    }
}
