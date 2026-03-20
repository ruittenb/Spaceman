//
//  InactiveStyle.swift
//  Spaceman
//
//  Controls how inactive spaces are visually distinguished from the active space.
//

import Foundation

enum InactiveStyle: Int, CaseIterable {
    case bordered = 0       // Active = filled box, Inactive = bordered outline
    case semiTransparent = 1 // Active = filled, Inactive = filled at reduced opacity

    var menuLabel: String {
        switch self {
        case .bordered:        return "Bordered"
        case .semiTransparent: return "Semi-transparent"
        }
    }
}
