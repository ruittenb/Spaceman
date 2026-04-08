//
//  IconWidth.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-10-02.
//

import Foundation

struct IconWidth: Codable {
    let left: CGFloat
    let right: CGFloat
    // For dual-row layout, use top/bottom to enable vertical hit testing (0 means single row)
    var top: CGFloat = 0
    var bottom: CGFloat = 0
    // Positive: space number; Negative: full-screen pseudo index (-1, -2)
    let index: Int
    // Global sequential position (from Space.spaceNumber), used for chained navigation
    var spaceNumber: Int = 0
}
