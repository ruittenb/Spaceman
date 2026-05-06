//
//  ChainingStrategy.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2024-08-28.
//

import Foundation

/// The result of calculating a chaining strategy for reaching
/// a space that has no direct keyboard shortcut.
enum ChainingStrategy: Equatable {
    /// Chain arrow keypresses from the current position.
    case chainFromCurrent(steps: Int, goRight: Bool)
    /// Jump to an anchor space, then chain remaining arrows.
    case jumpThenChain(
        anchorSwitchIndex: Int, steps: Int, goRight: Bool)
    /// Target is the anchor itself — direct switch.
    case directSwitch(switchIndex: Int)
    /// No reachable path.
    case unreachable
}
