//
//  RestorePreferencesCommand.swift
//  Spaceman
//

import Foundation
import Cocoa

class RestorePreferencesCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        try? PreferencesViewModel.restoreFromBackup()
        return nil
    }
}
