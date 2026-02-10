//
//  DisplayStyle.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 6/12/20.
//

import Foundation

enum DisplayStyle: Int, CaseIterable {
    case rects = 0
    case numbers = 1
    case numbersAndRects = 2
    case names = 3
    case numbersAndNames = 4

    var menuLabel: String {
        switch self {
        case .rects:           return "Rectangles"
        case .numbers:         return "Numbers"
        case .numbersAndRects: return "Rectangles with Numbers"
        case .names:           return "Names"
        case .numbersAndNames: return "Numbers and Names"
        }
    }
}
