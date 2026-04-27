//
//  ShrinkOverrides.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-04-22.
//

import Foundation

/// Overrides applied to IconCreator when auto-shrink is active.
/// Each field replaces the corresponding user preference for one render pass.
struct ShrinkOverrides {
    let iconSize: IconSize
    let displayStyle: IconText
    let showFullscreenSpaces: Bool
    let showNavArrows: Bool
    let showMissionControl: Bool
}
