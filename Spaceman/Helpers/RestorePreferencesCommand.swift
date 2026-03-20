//
//  RestorePreferencesCommand.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 16/03/2026.
//

import Foundation
import Cocoa

class RestorePreferencesCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        try? PreferencesViewModel.restoreFromBackup()
        return nil
    }
}
