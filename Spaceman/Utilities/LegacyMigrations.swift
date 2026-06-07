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
    static func perform() {
        removeObsoleteKeys()
        migrateSpaceByDesktopID()
        migrateHideInactiveSpaces()
        migrateRestartNumbering()
        migrateReverseDisplayOrder()
        migrateUseMinIconWidth()
        migrateDisplayStyleToDecoration()
        migrateDisplayStyleToIconText()
        migrateLayoutModeToDualRows()
        migrateDualRowsToRowLayout()
        migrateLayoutModeToIconSize()
        migrateHideFullscreenSpaces()
        migrateGestureSwitching()
    }

    /// Removes the keys that `perform()` migrates *to*.
    /// Call this before restoring a backup and re-running migrations, so the
    /// migration guards (`if object(forKey:) == nil`) don't skip over old-format
    /// keys present in the backup. Must be kept in sync with `perform()`.
    static func resetMigratedKeys() {
        let keys = [
            "visibleSpacesMode", "restartNumberingByDisplay", "horizontalDirection",
            "useVariableWidth", "decorationActive", "decorationInactive",
            "iconSize", "iconText", "rowLayout", "showFullscreenSpaces",
            "switchingMode"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Individual Migrations

    private static func removeObsoleteKeys() {
        UserDefaults.standard.removeObject(forKey: "spaceNameCache")
        UserDefaults.standard.removeObject(forKey: "allowChaining")
        UserDefaults.standard.removeObject(forKey: "navigateAnywhere")
    }

    private static func migrateSpaceByDesktopID() {
        if let data = UserDefaults.standard.data(forKey: "spaceNames"),
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
                UserDefaults.standard.set(newData, forKey: "spaceNames")
            }
        }
    }

    private static func migrateHideInactiveSpaces() {
        if UserDefaults.standard.object(forKey: "visibleSpacesMode") == nil {
            let hideInactiveSpaces = UserDefaults.standard.bool(forKey: "hideInactiveSpaces")
            let newValue: Int = hideInactiveSpaces
                ? VisibleSpacesMode.currentOnly.rawValue
                : VisibleSpacesMode.all.rawValue
            UserDefaults.standard.set(newValue, forKey: "visibleSpacesMode")
        }
        UserDefaults.standard.removeObject(forKey: "hideInactiveSpaces")
    }

    private static func migrateRestartNumbering() {
        if UserDefaults.standard.object(forKey: "restartNumberingByDisplay") == nil {
            let oldValue = UserDefaults.standard.bool(forKey: "restartNumberingByDesktop")
            UserDefaults.standard.set(oldValue, forKey: "restartNumberingByDisplay")
            UserDefaults.standard.removeObject(forKey: "restartNumberingByDesktop")
        }
    }

    private static func migrateReverseDisplayOrder() {
        if UserDefaults.standard.object(forKey: "horizontalDirection") == nil {
            let oldReverseDisplayOrder = UserDefaults.standard.bool(forKey: "reverseDisplayOrder")
            let newValue: Int = oldReverseDisplayOrder
                ? HorizontalDirection.reverseOrder.rawValue
                : HorizontalDirection.defaultOrder.rawValue
            UserDefaults.standard.set(newValue, forKey: "horizontalDirection")
            UserDefaults.standard.removeObject(forKey: "reverseDisplayOrder")
        }
    }

    private static func migrateUseMinIconWidth() {
        if UserDefaults.standard.object(forKey: "useVariableWidth") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "useMinIconWidth") as? Bool {
            UserDefaults.standard.set(!oldValue, forKey: "useVariableWidth")
            UserDefaults.standard.removeObject(forKey: "useMinIconWidth")
        }
    }

    private static func migrateDisplayStyleToDecoration() {
        if UserDefaults.standard.object(forKey: "decorationActive") == nil {
            let oldIconText = UserDefaults.standard.integer(forKey: "displayStyle")
            let oldInactiveStyle = UserDefaults.standard.integer(forKey: "inactiveStyle")

            if oldIconText == 1 {
                UserDefaults.standard.set(IconStyle.noDecoration.rawValue, forKey: "decorationActive")
                UserDefaults.standard.set(IconStyle.noDecoration.rawValue, forKey: "decorationInactive")
                UserDefaults.standard.set(IconText.numbers.rawValue, forKey: "iconText")
            } else {
                UserDefaults.standard.set(IconStyle.filledRounded.rawValue, forKey: "decorationActive")
                if oldInactiveStyle == 0 {
                    UserDefaults.standard.set(
                        IconStyle.borderedRounded.rawValue, forKey: "decorationInactive")
                } else {
                    UserDefaults.standard.set(
                        IconStyle.filledRounded.rawValue, forKey: "decorationInactive")
                }
            }
            UserDefaults.standard.removeObject(forKey: "inactiveStyle")
        }
    }

    private static func migrateDisplayStyleToIconText() {
        if UserDefaults.standard.object(forKey: "iconText") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "displayStyle") as? Int {
            UserDefaults.standard.set(oldValue, forKey: "iconText")
            UserDefaults.standard.removeObject(forKey: "displayStyle")
        }
    }

    private static func migrateLayoutModeToDualRows() {
        if UserDefaults.standard.object(forKey: "layoutMode") != nil,
           UserDefaults.standard.integer(forKey: "layoutMode") == 0 {
            UserDefaults.standard.set(RowLayout.twoRowsByColumn.rawValue, forKey: "rowLayout")
            UserDefaults.standard.set(IconSize.compact.rawValue, forKey: "layoutMode")
        }
    }

    private static func migrateDualRowsToRowLayout() {
        if UserDefaults.standard.object(forKey: "rowLayout") == nil,
           UserDefaults.standard.object(forKey: "dualRows") != nil {
            let dualRows = UserDefaults.standard.bool(forKey: "dualRows")
            if dualRows {
                let fillOrder = UserDefaults.standard.integer(forKey: "dualRowFillOrder")
                let newValue = fillOrder == 1
                    ? RowLayout.twoRowsByRow.rawValue
                    : RowLayout.twoRowsByColumn.rawValue
                UserDefaults.standard.set(newValue, forKey: "rowLayout")
            } else {
                UserDefaults.standard.set(RowLayout.singleRow.rawValue, forKey: "rowLayout")
            }
            UserDefaults.standard.removeObject(forKey: "dualRows")
            UserDefaults.standard.removeObject(forKey: "dualRowFillOrder")
        }
    }

    private static func migrateLayoutModeToIconSize() {
        // Old: compact=1, medium=2, large=3, extraLarge=4, narrow=5, enormous=6
        // New: narrow=0, compact=1, medium=2, large=3, extraLarge=4, enormous=5
        if UserDefaults.standard.object(forKey: "iconSize") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "layoutMode") as? Int {
            let newValue: Int
            switch oldValue {
            case 5:  newValue = IconSize.narrow.rawValue
            case 6:  newValue = IconSize.enormous.rawValue
            default: newValue = oldValue
            }
            UserDefaults.standard.set(newValue, forKey: "iconSize")
            UserDefaults.standard.removeObject(forKey: "layoutMode")
        }
    }

    private static func migrateHideFullscreenSpaces() {
        if UserDefaults.standard.object(forKey: "showFullscreenSpaces") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "hideFullscreenSpaces") as? Bool {
            UserDefaults.standard.set(!oldValue, forKey: "showFullscreenSpaces")
            UserDefaults.standard.removeObject(forKey: "hideFullscreenSpaces")
        }
    }

    private static func migrateGestureSwitching() {
        if UserDefaults.standard.object(forKey: "switchingMode") == nil,
           let oldValue = UserDefaults.standard.object(forKey: "useGestureSwitching") as? Bool {
            let mode = oldValue ? SwitchingMode.instant : SwitchingMode.smooth
            UserDefaults.standard.set(mode.rawValue, forKey: "switchingMode")
            UserDefaults.standard.removeObject(forKey: "useGestureSwitching")
        }
    }
}
