//
//  VisibleSpacesMode.swift
//  Spaceman
//
//  Created by ultravioletcatastrophe on 15/09/2025.
//  Controls which spaces are shown in the status bar.
//

import Foundation

enum VisibleSpacesMode: Int, CaseIterable {
    case all = 0
    case currentOnly = 1
    case neighbors = 2
}
