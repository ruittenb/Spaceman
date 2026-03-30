//
//  Constants.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 7/11/21.
//

import Foundation

struct Constants {
    static let maxSpaceNameLength = 10
    static let minMenuWidth: CGFloat = 350
    static let inactiveAlpha: CGFloat = 0.4

    static let filledBorderedFillAlpha: CGFloat = 0.3
    static let filledBorderedInactiveAlpha: CGFloat = 0.7

    enum AppInfo {
        static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        // swiftlint:disable:next force_unwrapping
        static let repo = URL(string: "https://github.com/ruittenb/Spaceman")!
        // swiftlint:disable:next force_unwrapping
        static let website = URL(string: "https://ruittenb.github.io/Spaceman/?" + compilationDate())!
    }

    //  23   = 277 px ; button distance
    //  18   = 219 px ; button width
    //  10   = 120 px ; left margin
    //   5   =  60 px ; gap
    //   2.5 =  30 px ; semi gap
    //   7.5 =  90 px ; void left

    static let sizes: [IconSize: GuiSize] = [
        .narrow: GuiSize(
            GAP_WIDTH_SPACES: 2,
            GAP_WIDTH_DISPLAYS: 8,
            GAP_HEIGHT_ROWS: 0,
            HORIZONTAL_PADDING: 3,
            VERTICAL_PADDING: 3,
            BORDER_WIDTH: 1,
            FONT_SIZE: 10
        ),
        .compact: GuiSize(
            GAP_WIDTH_SPACES: 3,
            GAP_WIDTH_DISPLAYS: 10,
            GAP_HEIGHT_ROWS: 0,
            HORIZONTAL_PADDING: 4,
            VERTICAL_PADDING: 3,
            BORDER_WIDTH: 1,
            FONT_SIZE: 10
        ),
        .medium: GuiSize(
            GAP_WIDTH_SPACES: 4,
            GAP_WIDTH_DISPLAYS: 12,
            GAP_HEIGHT_ROWS: 0,
            HORIZONTAL_PADDING: 5,
            VERTICAL_PADDING: 3,
            BORDER_WIDTH: 1.17,
            FONT_SIZE: 10
        ),
        .large: GuiSize(
            GAP_WIDTH_SPACES: 5,
            GAP_WIDTH_DISPLAYS: 14,
            GAP_HEIGHT_ROWS: 0,
            HORIZONTAL_PADDING: 6,
            VERTICAL_PADDING: 3.6,
            BORDER_WIDTH: 1.33,
            FONT_SIZE: 12
        ),
        .extraLarge: GuiSize(
            GAP_WIDTH_SPACES: 6,
            GAP_WIDTH_DISPLAYS: 16,
            GAP_HEIGHT_ROWS: 0,
            HORIZONTAL_PADDING: 7,
            VERTICAL_PADDING: 4.5,
            BORDER_WIDTH: 1.67,
            FONT_SIZE: 14
        ),
        .enormous: GuiSize(
            GAP_WIDTH_SPACES: 6,
            GAP_WIDTH_DISPLAYS: 16,
            GAP_HEIGHT_ROWS: 0,
            HORIZONTAL_PADDING: 8,
            VERTICAL_PADDING: 5.25,
            BORDER_WIDTH: 2,
            FONT_SIZE: 16
        )
    ]

    static let sizesTwoRows: [IconSize: GuiSize] = [
        .compact: GuiSize(
            GAP_WIDTH_SPACES: 1,
            GAP_WIDTH_DISPLAYS: 6,
            GAP_HEIGHT_ROWS: 1,
            HORIZONTAL_PADDING: 2,
            VERTICAL_PADDING: 2,
            BORDER_WIDTH: 1,
            FONT_SIZE: 9
        ),
        .medium: GuiSize(
            GAP_WIDTH_SPACES: 2,
            GAP_WIDTH_DISPLAYS: 8,
            GAP_HEIGHT_ROWS: 2,
            HORIZONTAL_PADDING: 2.5,
            VERTICAL_PADDING: 1.75,
            BORDER_WIDTH: 1,
            FONT_SIZE: 9
        ),
        .large: GuiSize(
            GAP_WIDTH_SPACES: 3,
            GAP_WIDTH_DISPLAYS: 10,
            GAP_HEIGHT_ROWS: 2,
            HORIZONTAL_PADDING: 3,
            VERTICAL_PADDING: 1.5,
            BORDER_WIDTH: 1,
            FONT_SIZE: 10
        )
    ]

    /// Returns the two-row GuiSize for the given size, mapping to the
    /// nearest available size if the size has no two-row entry.
    static func nearestTwoRowSize(for size: IconSize) -> GuiSize {
        let key: IconSize
        switch size {
        case .narrow, .compact:              key = .compact
        case .medium:                        key = .medium
        case .large, .extraLarge, .enormous: key = .large
        }
        // swiftlint:disable:next force_unwrapping
        return sizesTwoRows[key]!
    }
}
