//
//  SpaceNameInfo.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 6/12/20.
//

import Foundation

struct SpaceNameInfo: Hashable, Codable {
    let spaceNum: Int
    let spaceName: String
    let spaceByDesktopID: String
    // Current display index after applying user display ordering (1..D). Optional for backward compatibility.
    var currentDisplayIndex: Int? = nil
    // Current global order in status bar/menu (1..N) after applying display sorting.
    var currentOrder: Int? = nil
}
