//
//  GestureSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-05.
//  Co-author: Claude Code
//

import CoreGraphics
import Foundation

/// Switches spaces by posting synthetic dock-swipe CGEvents,
/// bypassing the need for keyboard shortcuts entirely.
/// Based on the technique from InstantSpaceSwitcher by jurplel.
class GestureSwitcher {

    // MARK: - Undocumented CGEvent field constants

    // CGEventField(rawValue:) is optional due to RawRepresentable, but it wraps
    // any UInt32 without validation — these will never return nil.
    // swiftlint:disable force_unwrapping
    private static let eventTypeField = CGEventField(rawValue: 55)!
    private static let gestureHIDType = CGEventField(rawValue: 110)!
    private static let swipeMotion = CGEventField(rawValue: 123)!
    private static let swipeProgress = CGEventField(rawValue: 124)!
    private static let swipeVelocityX = CGEventField(rawValue: 129)!
    private static let swipeVelocityY = CGEventField(rawValue: 130)!
    private static let gesturePhase = CGEventField(rawValue: 132)!
    // swiftlint:enable force_unwrapping

    // Event type / HID type constants
    private static let dockControl: Int64 = 30
    private static let hidDockSwipe: Int64 = 23
    private static let motionHorizontal: Int64 = 1

    // Gesture phases
    private static let phaseBegan: Int64 = 1
    private static let phaseChanged: Int64 = 2
    private static let phaseEnded: Int64 = 4

    private static let speedFast: Double = 10.0
    private static let speedInstant: Double = 2000.0

    // MARK: - Public API

    /// Switch from the current space to the target space on the same display.
    /// Returns `false` if the spaces are on different displays (caller should
    /// fall back to AppleScript).
    func switchToSpace(
        target: Space, current: Space, spaces: [Space],
        mode: SwitchingMode
    ) -> Bool {
        guard target.displayID == current.displayID else { return false }
        guard !target.isCurrentSpace else { return true }

        let displaySpaces = spaces
            .filter { $0.displayID == target.displayID }
            .sorted { $0.spaceNumber < $1.spaceNumber }

        guard let currentIndex = displaySpaces.firstIndex(
            where: { $0.spaceID == current.spaceID }),
              let targetIndex = displaySpaces.firstIndex(
                where: { $0.spaceID == target.spaceID })
        else {
            return false
        }

        let steps = abs(targetIndex - currentIndex)
        guard steps > 0 else { return true }

        let goRight = targetIndex > currentIndex
        let speed = mode == .instant ? Self.speedInstant : Self.speedFast
        let velocity = speed * Double(steps)

        for _ in 0..<steps {
            performSwitchGesture(goRight: goRight, velocity: velocity)
        }
        return true
    }

    /// Switch one space left or right (for prev/next arrow buttons).
    func switchRelative(goRight: Bool, mode: SwitchingMode) {
        let speed = mode == .instant ? Self.speedInstant : Self.speedFast
        performSwitchGesture(goRight: goRight, velocity: speed)
    }

    // MARK: - Private

    private func performSwitchGesture(
        goRight: Bool, velocity: Double
    ) {
        // All three phases are required for reliable switching.
        postDockSwipe(phase: Self.phaseBegan, goRight: goRight,
                      velocity: velocity)
        postDockSwipe(phase: Self.phaseChanged, goRight: goRight,
                      velocity: velocity)
        postDockSwipe(phase: Self.phaseEnded, goRight: goRight,
                      velocity: velocity)
    }

    private func postDockSwipe(
        phase: Int64, goRight: Bool, velocity: Double
    ) {
        let progress = goRight
            ? Double(Float.leastNonzeroMagnitude)
            : -Double(Float.leastNonzeroMagnitude)
        let vel = goRight ? velocity : -velocity

        guard let event = CGEvent(source: nil) else { return }
        event.setIntegerValueField(Self.eventTypeField, value: Self.dockControl)
        event.setIntegerValueField(Self.gestureHIDType, value: Self.hidDockSwipe)
        event.setIntegerValueField(Self.gesturePhase, value: phase)
        event.setDoubleValueField(Self.swipeProgress, value: progress)
        event.setIntegerValueField(Self.swipeMotion, value: Self.motionHorizontal)
        event.setDoubleValueField(Self.swipeVelocityX, value: vel)
        event.setDoubleValueField(Self.swipeVelocityY, value: vel)
        event.post(tap: .cgSessionEventTap)
    }
}
