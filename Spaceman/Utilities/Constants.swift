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
            gapWidthSpaces: 2,
            gapWidthDisplays: 8,
            gapHeightRows: 0,
            horizontalPadding: 3,
            verticalPadding: 3,
            borderWidth: 1,
            fontSize: 10
        ),
        .compact: GuiSize(
            gapWidthSpaces: 3,
            gapWidthDisplays: 10,
            gapHeightRows: 0,
            horizontalPadding: 4,
            verticalPadding: 3,
            borderWidth: 1,
            fontSize: 10
        ),
        .medium: GuiSize(
            gapWidthSpaces: 4,
            gapWidthDisplays: 12,
            gapHeightRows: 0,
            horizontalPadding: 5,
            verticalPadding: 3,
            borderWidth: 1.17,
            fontSize: 10
        ),
        .large: GuiSize(
            gapWidthSpaces: 5,
            gapWidthDisplays: 14,
            gapHeightRows: 0,
            horizontalPadding: 6,
            verticalPadding: 3.6,
            borderWidth: 1.33,
            fontSize: 12
        ),
        .extraLarge: GuiSize(
            gapWidthSpaces: 6,
            gapWidthDisplays: 16,
            gapHeightRows: 0,
            horizontalPadding: 7,
            verticalPadding: 4.5,
            borderWidth: 1.67,
            fontSize: 14
        ),
        .enormous: GuiSize(
            gapWidthSpaces: 6,
            gapWidthDisplays: 16,
            gapHeightRows: 0,
            horizontalPadding: 8,
            verticalPadding: 5.25,
            borderWidth: 2,
            fontSize: 16
        )
    ]

    static let sizesTwoRows: [IconSize: GuiSize] = [
        .compact: GuiSize(
            gapWidthSpaces: 1,
            gapWidthDisplays: 6,
            gapHeightRows: 1,
            horizontalPadding: 2,
            verticalPadding: 2,
            borderWidth: 1,
            fontSize: 9
        ),
        .medium: GuiSize(
            gapWidthSpaces: 2,
            gapWidthDisplays: 8,
            gapHeightRows: 2,
            horizontalPadding: 2.5,
            verticalPadding: 1.75,
            borderWidth: 1,
            fontSize: 9
        ),
        .large: GuiSize(
            gapWidthSpaces: 3,
            gapWidthDisplays: 10,
            gapHeightRows: 2,
            horizontalPadding: 3,
            verticalPadding: 1.5,
            borderWidth: 1,
            fontSize: 10
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
