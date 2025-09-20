//
//  LayoutMode.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 27/09/2024.
//

import Foundation

enum LayoutMode: Int {
    case compact, medium, large, dualRows
}

// Display arrangement preferences (shared by UI and sorting)
enum DisplayOrderPriority: Int { case horizontal, vertical }
enum HorizontalDirection: Int { case leftToRight, rightToLeft }
enum VerticalDirection: Int { case topToBottom, bottomToTop }

// Dual-row fill order (visual ordering of spaces in dual-row layout)
enum DualRowFillOrder: Int { case columnMajor, rowMajor }
