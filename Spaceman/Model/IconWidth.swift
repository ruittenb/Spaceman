//
//  IconWidth.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 02/10/2024.
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
}
