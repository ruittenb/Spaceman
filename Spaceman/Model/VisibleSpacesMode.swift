//
//  VisibleSpacesMode.swift
//  Spaceman
//
//  Created by ultravioletcatastrophe on 16/9/2025
//  Controls which spaces are shown in the status bar.
//

import Foundation

enum VisibleSpacesMode: Int, CaseIterable {
    case all = 0
    case neighbors = 1
    case currentOnly = 2

    var menuLabel: String {
        switch self {
        case .all:         return "All Spaces"
        case .neighbors:   return "Nearby Spaces"
        case .currentOnly: return "Current Only"
        }
    }
}
