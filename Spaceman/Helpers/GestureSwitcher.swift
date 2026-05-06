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
    fileprivate static let eventTypeField = CGEventField(rawValue: 55)!
    fileprivate static let gestureHIDType = CGEventField(rawValue: 110)!
    fileprivate static let swipeMotion = CGEventField(rawValue: 123)!
    fileprivate static let swipeProgress = CGEventField(rawValue: 124)!
    fileprivate static let swipeVelocityX = CGEventField(rawValue: 129)!
    fileprivate static let swipeVelocityY = CGEventField(rawValue: 130)!
    fileprivate static let gesturePhase = CGEventField(rawValue: 132)!
    // swiftlint:enable force_unwrapping

    // Event type / HID type constants
    fileprivate static let dockControl: Int64 = 30
    fileprivate static let hidDockSwipe: Int64 = 23
    fileprivate static let motionHorizontal: Int64 = 1

    // Gesture phases
    private static let phaseBegan: Int64 = 1
    private static let phaseChanged: Int64 = 2
    private static let phaseEnded: Int64 = 4

    static let speedFast: Double = 10.0
    static let speedInstant: Double = 2000.0

    // MARK: - Pure computation (testable)

    struct SwitchCalculation {
        let steps: Int
        let goRight: Bool
        let velocity: Double
    }

    /// Calculate the switch parameters without performing it.
    /// Returns nil if spaces are not on the same display or
    /// the target/current can't be found in the spaces array.
    static func calculateSwitch(
        target: Space, current: Space, spaces: [Space],
        mode: SwitchingMode
    ) -> SwitchCalculation? {
        let displaySpaces = spaces
            .filter { $0.displayID == target.displayID }
            .sorted { $0.spaceNumber < $1.spaceNumber }

        guard let currentIndex = displaySpaces.firstIndex(
            where: { $0.spaceID == current.spaceID }),
              let targetIndex = displaySpaces.firstIndex(
                where: { $0.spaceID == target.spaceID })
        else {
            return nil
        }

        let steps = abs(targetIndex - currentIndex)
        guard steps > 0 else { return nil }

        let goRight = targetIndex > currentIndex
        let speed = mode == .instant ? speedInstant : speedFast
        let velocity = speed * Double(steps)

        return SwitchCalculation(
            steps: steps, goRight: goRight, velocity: velocity)
    }

    // MARK: - Event posting (injectable for testing)

    private let eventPoster: EventPosting

    init(eventPoster: EventPosting = SystemEventPoster()) {
        self.eventPoster = eventPoster
    }

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

        guard let calc = Self.calculateSwitch(
            target: target, current: current,
            spaces: spaces, mode: mode)
        else {
            return true
        }

        for _ in 0..<calc.steps {
            performSwitchGesture(
                goRight: calc.goRight, velocity: calc.velocity)
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
        eventPoster.postDockSwipe(
            phase: Self.phaseBegan, goRight: goRight,
            velocity: velocity)
        eventPoster.postDockSwipe(
            phase: Self.phaseChanged, goRight: goRight,
            velocity: velocity)
        eventPoster.postDockSwipe(
            phase: Self.phaseEnded, goRight: goRight,
            velocity: velocity)
    }
}

// MARK: - Event posting protocol

protocol EventPosting {
    func postDockSwipe(phase: Int64, goRight: Bool, velocity: Double)
}

/// Posts real CGEvents to the system.
struct SystemEventPoster: EventPosting {
    func postDockSwipe(
        phase: Int64, goRight: Bool, velocity: Double
    ) {
        let progress = goRight
            ? Double(Float.leastNonzeroMagnitude)
            : -Double(Float.leastNonzeroMagnitude)
        let vel = goRight ? velocity : -velocity

        guard let event = CGEvent(source: nil) else { return }
        event.setIntegerValueField(
            GestureSwitcher.eventTypeField,
            value: GestureSwitcher.dockControl)
        event.setIntegerValueField(
            GestureSwitcher.gestureHIDType,
            value: GestureSwitcher.hidDockSwipe)
        event.setIntegerValueField(
            GestureSwitcher.gesturePhase, value: phase)
        event.setDoubleValueField(
            GestureSwitcher.swipeProgress, value: progress)
        event.setIntegerValueField(
            GestureSwitcher.swipeMotion,
            value: GestureSwitcher.motionHorizontal)
        event.setDoubleValueField(
            GestureSwitcher.swipeVelocityX, value: vel)
        event.setDoubleValueField(
            GestureSwitcher.swipeVelocityY, value: vel)
        event.post(tap: .cgSessionEventTap)
    }
}
