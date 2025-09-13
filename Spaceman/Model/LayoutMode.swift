//
//  LayoutMode.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 27/09/2024.
//

import Foundation

enum LayoutMode: Int {
    case compact, medium, large
}

// Display arrangement preferences (shared by UI and sorting)
enum DisplaySortPriority: Int { case horizontal, vertical }
enum HorizontalSortOrder: Int { case leftToRight, rightToLeft }
enum VerticalSortOrder: Int { case topToBottom, bottomToTop }
