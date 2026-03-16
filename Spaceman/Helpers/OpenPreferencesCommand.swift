//
//  OpenPreferencesCommand.swift
//  Spaceman
//
//  Created by Claude Code on 21/09/2025.
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
