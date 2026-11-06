//
//  AppConstants.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 24/11/20.
//

import Foundation

/// Notification posted when the user changes a setting that requires a redraw.
let settingsChangedName = NSNotification.Name("SettingsChanged")

/// Notification posted by the auto-refresh timer.
let autoRefreshTriggeredName = NSNotification.Name("AutoRefreshTriggered")

/// Notification posted when preferences are restored from backup.
let preferencesRestoredName = NSNotification.Name("PreferencesRestored")

/// Notify the app that a setting changed and spaces should be redrawn.
func postSettingsChanged() {
    NotificationCenter.default.post(name: settingsChangedName, object: nil)
}

/// Notify the app that preferences were restored from backup.
func postPreferencesRestored() {
    NotificationCenter.default.post(name: preferencesRestoredName, object: nil)
}
