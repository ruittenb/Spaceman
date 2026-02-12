//
//  Constants.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 7/11/21.
//

import Foundation

struct Constants {
    enum AppInfo {
        static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        // swiftlint:disable:next force_unwrapping
        static let repo = URL(string: "https://github.com/ruittenb/Spaceman")!
        // swiftlint:disable:next force_unwrapping
        static let website = URL(string: "https://ruittenb.github.io/Spaceman/?20251017")!
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
            ICON_WIDTH_SMALL: 16,
            ICON_WIDTH_LARGE: 24,
            ICON_WIDTH_XLARGE: 36,
            ICON_HEIGHT: 10,
            FONT_SIZE: 9
        ),
        .compact: GuiSize(
            GAP_WIDTH_SPACES: 3,
            GAP_WIDTH_DISPLAYS: 8,
            GAP_HEIGHT_DUALROWS: 0,
            ICON_WIDTH_SMALL: 16,
            ICON_WIDTH_LARGE: 24,
            ICON_WIDTH_XLARGE: 36,
            ICON_HEIGHT: 12,
            FONT_SIZE: 10
        ),
        .medium: GuiSize(
            GAP_WIDTH_SPACES: 5,
            GAP_WIDTH_DISPLAYS: 12,
            GAP_HEIGHT_DUALROWS: 0,
            ICON_WIDTH_SMALL: 18,
            ICON_WIDTH_LARGE: 32,
            ICON_WIDTH_XLARGE: 42,
            ICON_HEIGHT: 12,
            FONT_SIZE: 10
        ),
        .large: GuiSize(
            GAP_WIDTH_SPACES: 5,
            GAP_WIDTH_DISPLAYS: 14,
            GAP_HEIGHT_DUALROWS: 0,
            ICON_WIDTH_SMALL: 20,
            ICON_WIDTH_LARGE: 34,
            ICON_WIDTH_XLARGE: 49,
            ICON_HEIGHT: 14,
            FONT_SIZE: 12
        ),
        .extraLarge: GuiSize(
            GAP_WIDTH_SPACES: 6,
            GAP_WIDTH_DISPLAYS: 16,
            GAP_HEIGHT_DUALROWS: 0,
            ICON_WIDTH_SMALL: 24,
            ICON_WIDTH_LARGE: 44,
            ICON_WIDTH_XLARGE: 62,
            ICON_HEIGHT: 16,
            FONT_SIZE: 14
        )
    ]
}
