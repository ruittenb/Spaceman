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

    enum AppInfo {
        static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        // swiftlint:disable:next force_unwrapping
        static let repo = URL(string: "https://github.com/ruittenb/Spaceman")!
        // swiftlint:disable:next force_unwrapping
        static let website = URL(string: "https://ruittenb.github.io/Spaceman/?20260324")!
    }

    //  23   = 277 px ; button distance
    //  18   = 219 px ; button width
    //  10   = 120 px ; left margin
    //   5   =  60 px ; gap
    //   2.5 =  30 px ; semi gap
    //   7.5 =  90 px ; void left

    static let sizes: [LayoutMode: GuiSize] = [
        .dualRows: GuiSize(
            GAP_WIDTH_SPACES: 3,
            GAP_WIDTH_DISPLAYS: 8,
            GAP_HEIGHT_DUALROWS: 3,
            HORIZONTAL_PADDING: 6,
            VERTICAL_PADDING: 1.5,
            BORDER_WIDTH: 1,
            FONT_SIZE: 9
        ),
        .narrow: GuiSize(
            GAP_WIDTH_SPACES: 2,
            GAP_WIDTH_DISPLAYS: 8,
            GAP_HEIGHT_DUALROWS: 0,
            HORIZONTAL_PADDING: 3,
            VERTICAL_PADDING: 3,
            BORDER_WIDTH: 1,
            FONT_SIZE: 10
        ),
        .compact: GuiSize(
            GAP_WIDTH_SPACES: 3,
            GAP_WIDTH_DISPLAYS: 10,
            GAP_HEIGHT_DUALROWS: 0,
            HORIZONTAL_PADDING: 4,
            VERTICAL_PADDING: 3,
            BORDER_WIDTH: 1,
            FONT_SIZE: 10
        ),
        .medium: GuiSize(
            GAP_WIDTH_SPACES: 4,
            GAP_WIDTH_DISPLAYS: 12,
            GAP_HEIGHT_DUALROWS: 0,
            HORIZONTAL_PADDING: 5,
            VERTICAL_PADDING: 3,
            BORDER_WIDTH: 1,
            FONT_SIZE: 10
        ),
        .large: GuiSize(
            GAP_WIDTH_SPACES: 5,
            GAP_WIDTH_DISPLAYS: 14,
            GAP_HEIGHT_DUALROWS: 0,
            HORIZONTAL_PADDING: 6,
            VERTICAL_PADDING: 3.75,
            BORDER_WIDTH: 1.33,
            FONT_SIZE: 12
        ),
        .extraLarge: GuiSize(
            GAP_WIDTH_SPACES: 6,
            GAP_WIDTH_DISPLAYS: 16,
            GAP_HEIGHT_DUALROWS: 0,
            HORIZONTAL_PADDING: 7,
            VERTICAL_PADDING: 4.5,
            BORDER_WIDTH: 1.67,
            FONT_SIZE: 14
        )
    ]
}
