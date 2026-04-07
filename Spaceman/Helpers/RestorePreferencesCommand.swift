//
//  RestorePreferencesCommand.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-03-16.
//

import Foundation
import Cocoa

class RestorePreferencesCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        try? PreferencesViewModel.restoreFromBackup()
        return nil
    }
}
