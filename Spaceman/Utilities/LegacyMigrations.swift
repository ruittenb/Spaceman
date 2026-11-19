//
//  LegacyMigrations.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-06-07.
//  Co-author: Claude Code
//

import Foundation

struct LegacyMigrations {

    /// Run all legacy UserDefaults migrations in order.
    static func perform(defaults: UserDefaults = .standard) {
        removeObsoleteKeys(defaults)
        migrateSpaceByDesktopID(defaults)
        migrateHideInactiveSpaces(defaults)
        migrateRestartNumbering(defaults)
        migrateReverseDisplayOrder(defaults)
        migrateUseMinIconWidth(defaults)
        migrateDisplayStyleToDecoration(defaults)
        migrateDisplayStyleToIconText(defaults)
        migrateLayoutModeToDualRows(defaults)
        migrateDualRowsToRowLayout(defaults)
        migrateLayoutModeToIconSize(defaults)
        migrateHideFullscreenSpaces(defaults)
        migrateGestureSwitching(defaults)
    }

    /// Removes the keys that `perform()` migrates *to*.
    /// Call this before restoring a backup and re-running migrations, so the
    /// migration guards (`if object(forKey:) == nil`) don't skip over old-format
    /// keys present in the backup. Must be kept in sync with `perform()`.
    static func resetMigratedKeys(defaults: UserDefaults = .standard) {
        let keys = [
            "visibleSpacesMode", "restartNumberingByDisplay", "horizontalDirection",
            "useVariableWidth", "decorationActive", "decorationInactive",
            "iconSize", "iconText", "rowLayout", "showFullscreenSpaces",
            "switchingMode"
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Individual Migrations

    private static func removeObsoleteKeys(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: "spaceNameCache")
        defaults.removeObject(forKey: "allowChaining")
        defaults.removeObject(forKey: "navigateAnywhere")
    }

    private static func migrateSpaceByDesktopID(_ defaults: UserDefaults) {
        if let data = defaults.data(forKey: "spaceNames"),
           var outer = try? PropertyListSerialization.propertyList(
               from: data, format: nil) as? [String: [String: Any]] {
            var changed = false
            for (key, var inner) in outer {
                if let value = inner.removeValue(forKey: "spaceByDesktopID") {
                    inner["spaceLabel"] = value
                    outer[key] = inner
                    changed = true
                }
            }
            if changed,
               let newData = try? PropertyListSerialization.data(
                   fromPropertyList: outer, format: .binary, options: 0) {
                defaults.set(newData, forKey: "spaceNames")
            }
        }
    }

    private static func migrateHideInactiveSpaces(_ defaults: UserDefaults) {
        if defaults.object(forKey: "visibleSpacesMode") == nil {
            let hideInactiveSpaces = defaults.bool(forKey: "hideInactiveSpaces")
            let newValue: Int = hideInactiveSpaces
                ? VisibleSpacesMode.currentOnly.rawValue
                : VisibleSpacesMode.all.rawValue
            defaults.set(newValue, forKey: "visibleSpacesMode")
        }
        defaults.removeObject(forKey: "hideInactiveSpaces")
    }

    private static func migrateRestartNumbering(_ defaults: UserDefaults) {
        if defaults.object(forKey: "restartNumberingByDisplay") == nil {
            let oldValue = defaults.bool(forKey: "restartNumberingByDesktop")
            defaults.set(oldValue, forKey: "restartNumberingByDisplay")
            defaults.removeObject(forKey: "restartNumberingByDesktop")
        }
    }

    private static func migrateReverseDisplayOrder(_ defaults: UserDefaults) {
        if defaults.object(forKey: "horizontalDirection") == nil {
            let oldReverseDisplayOrder = defaults.bool(forKey: "reverseDisplayOrder")
            let newValue: Int = oldReverseDisplayOrder
                ? HorizontalDirection.reverseOrder.rawValue
                : HorizontalDirection.defaultOrder.rawValue
            defaults.set(newValue, forKey: "horizontalDirection")
            defaults.removeObject(forKey: "reverseDisplayOrder")
        }
    }

    private static func migrateUseMinIconWidth(_ defaults: UserDefaults) {
        if defaults.object(forKey: "useVariableWidth") == nil,
           let oldValue = defaults.object(forKey: "useMinIconWidth") as? Bool {
            defaults.set(!oldValue, forKey: "useVariableWidth")
            defaults.removeObject(forKey: "useMinIconWidth")
        }
    }

    private static func migrateDisplayStyleToDecoration(_ defaults: UserDefaults) {
        if defaults.object(forKey: "decorationActive") == nil {
            let oldIconText = defaults.integer(forKey: "displayStyle")
            let oldInactiveStyle = defaults.integer(forKey: "inactiveStyle")

            if oldIconText == 1 {
                defaults.set(IconStyle.noDecoration.rawValue, forKey: "decorationActive")
                defaults.set(IconStyle.noDecoration.rawValue, forKey: "decorationInactive")
                defaults.set(IconText.numbers.rawValue, forKey: "iconText")
            } else {
                defaults.set(IconStyle.filledRounded.rawValue, forKey: "decorationActive")
                if oldInactiveStyle == 0 {
                    defaults.set(
                        IconStyle.borderedRounded.rawValue, forKey: "decorationInactive")
                } else {
                    defaults.set(
                        IconStyle.filledRounded.rawValue, forKey: "decorationInactive")
                }
            }
            defaults.removeObject(forKey: "inactiveStyle")
        }
    }

    private static func migrateDisplayStyleToIconText(_ defaults: UserDefaults) {
        if defaults.object(forKey: "iconText") == nil,
           let oldValue = defaults.object(forKey: "displayStyle") as? Int {
            defaults.set(oldValue, forKey: "iconText")
            defaults.removeObject(forKey: "displayStyle")
        }
    }

    private static func migrateLayoutModeToDualRows(_ defaults: UserDefaults) {
        if defaults.object(forKey: "layoutMode") != nil,
           defaults.integer(forKey: "layoutMode") == 0 {
            defaults.set(RowLayout.twoRowsByColumn.rawValue, forKey: "rowLayout")
            defaults.set(IconSize.compact.rawValue, forKey: "layoutMode")
        }
    }

    private static func migrateDualRowsToRowLayout(_ defaults: UserDefaults) {
        if defaults.object(forKey: "rowLayout") == nil,
           defaults.object(forKey: "dualRows") != nil {
            let dualRows = defaults.bool(forKey: "dualRows")
            if dualRows {
                let fillOrder = defaults.integer(forKey: "dualRowFillOrder")
                let newValue = fillOrder == 1
                    ? RowLayout.twoRowsByRow.rawValue
                    : RowLayout.twoRowsByColumn.rawValue
                defaults.set(newValue, forKey: "rowLayout")
            } else {
                defaults.set(RowLayout.singleRow.rawValue, forKey: "rowLayout")
            }
            defaults.removeObject(forKey: "dualRows")
            defaults.removeObject(forKey: "dualRowFillOrder")
        }
    }

    private static func migrateLayoutModeToIconSize(_ defaults: UserDefaults) {
        // Old: compact=1, medium=2, large=3, extraLarge=4, narrow=5, enormous=6
        // New: narrow=0, compact=1, medium=2, large=3, extraLarge=4, enormous=5
        if defaults.object(forKey: "iconSize") == nil,
           let oldValue = defaults.object(forKey: "layoutMode") as? Int {
            let newValue: Int
            switch oldValue {
            case 5:  newValue = IconSize.narrow.rawValue
            case 6:  newValue = IconSize.enormous.rawValue
            default: newValue = oldValue
            }
            defaults.set(newValue, forKey: "iconSize")
            defaults.removeObject(forKey: "layoutMode")
        }
    }

    private static func migrateHideFullscreenSpaces(_ defaults: UserDefaults) {
        if defaults.object(forKey: "showFullscreenSpaces") == nil,
           let oldValue = defaults.object(forKey: "hideFullscreenSpaces") as? Bool {
            defaults.set(!oldValue, forKey: "showFullscreenSpaces")
            defaults.removeObject(forKey: "hideFullscreenSpaces")
        }
    }

    private static func migrateGestureSwitching(_ defaults: UserDefaults) {
        if defaults.object(forKey: "switchingMode") == nil,
           let oldValue = defaults.object(forKey: "useGestureSwitching") as? Bool {
            let mode = oldValue ? SwitchingMode.instant : SwitchingMode.smooth
            defaults.set(mode.rawValue, forKey: "switchingMode")
            defaults.removeObject(forKey: "useGestureSwitching")
        }
    }
}
