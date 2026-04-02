//
//  RowLayout.swift
//  Spaceman
//
//  Created by Claude Code on 2026-04-02.
//

import Foundation

enum RowLayout: Int, CaseIterable {
    case singleRow = 0
    case twoRowsByRow = 1
    case twoRowsByColumn = 2

    var isTwoRows: Bool {
        self != .singleRow
    }

    /// Short label for the preferences segmented picker.
    var pickerLabel: String {
        switch self {
        case .singleRow:       return String(localized: "One")
        case .twoRowsByRow:    return String(localized: "Two, by rows")
        case .twoRowsByColumn: return String(localized: "Two, by cols")
        }
    }

    /// Longer label for the right-click menu.
    var menuLabel: String {
        switch self {
        case .singleRow:       return String(localized: "Single Row")
        case .twoRowsByRow:    return String(localized: "Two Rows, by Rows")
        case .twoRowsByColumn: return String(localized: "Two Rows, by Columns")
        }
    }
}
