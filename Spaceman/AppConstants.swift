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

/// Notify the app that a setting changed and spaces should be redrawn.
func postSettingsChanged() {
    NotificationCenter.default.post(name: settingsChangedName, object: nil)
}
