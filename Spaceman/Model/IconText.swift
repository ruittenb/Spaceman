//
//  IconText.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 6/12/20.
//

import Foundation

enum IconText: Int, CaseIterable {
    case noText = 0
    case numbers = 2
    case names = 3
    case numbersAndNames = 4

    var menuLabel: String {
        switch self {
        case .noText:           return String(localized: "No Text")
        case .numbers:         return String(localized: "Numbers")
        case .names:           return String(localized: "Names")
        case .numbersAndNames: return String(localized: "Numbers and Names")
        }
    }
}
