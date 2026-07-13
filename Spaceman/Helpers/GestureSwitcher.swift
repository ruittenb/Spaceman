//
//  GestureSwitcher.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-05-05.
//  Co-author: Claude Code
//

import CoreGraphics
import Foundation

// MARK: - macOS 27 IOHID Payload Structures
//
// macOS 27 validates synthetic dock-swipe CGEvents against a serialized IOHID
// queue payload attached to CGEvent field 4205. Without this payload, synthetic
// gesture events are silently ignored.
//
// The workaround:
// 1. Create CGEvent with standard gesture fields
// 2. Serialize via CGEventCreateData()
// 3. Append IOHIDSystemQueueElement payload with Field 4205 tag
// 4. Deserialize via CGEventCreateFromData()
// 5. Post the augmented event
//
// Struct layouts and field values derived from:
// - joshuarli/iss: https://github.com/joshuarli/iss (MIT License)
// - mgbowen/FasterSwiper: https://github.com/mgbowen/FasterSwiper
// - CGEvent serialization format: https://gist.github.com/mgbowen/5548f18ada2e37b23c9e86a8d80b71dc
//
// All values are little-endian. Position/velocity use 16.16 fixed-point format.

/// Base structure embedded in all IOHID event types (16 bytes).
private struct IOHIDEventBase {
    var size: UInt32         // Total size of this event structure
    var type: UInt32         // Event type: 23 = FluidTouchGesture, 9 = Velocity
    var options: UInt32      // Gesture phase encoded in high byte: (phase & 0xFF) << 24
    var depth: UInt8         // Nesting depth (1 for velocity as child of gesture)
    var reserved: (UInt8, UInt8, UInt8)  // Padding for alignment
}

/// Fluid touch gesture event data (40 bytes total).
/// Describes a dock swipe gesture with position and progress.
private struct IOHIDFluidTouchGestureData {
    var base: IOHIDEventBase      // 16 bytes - includes type=23 (FluidTouchGesture)
    var positionX: Int32          // 16.16 fixed-point X position
    var positionY: Int32          // 16.16 fixed-point Y position
    var positionZ: Int32          // 16.16 fixed-point Z position (usually 0)
    var swipeMask: UInt32         // Direction flags (not used for dock swipe)
    var gestureMotion: UInt16     // Motion axis: 1 = horizontal, 2 = vertical
    var gestureFlavor: UInt16     // Gesture type: 3 = kIOHIDGestureFlavorDockPrimary
    var swipeProgress: Int32      // 16.16 fixed-point swipe progress (-1.0 to 1.0)
}

/// Velocity event data (28 bytes total).
/// Attached as child event when gesture has velocity or at phase Ended.
private struct IOHIDVelocityEventData {
    var base: IOHIDEventBase      // 16 bytes - includes type=9 (Velocity), depth=1
    var velocityX: Int32          // 16.16 fixed-point X velocity
    var velocityY: Int32          // 16.16 fixed-point Y velocity
    var velocityZ: Int32          // 16.16 fixed-point Z velocity (usually 0)
}

/// Queue element header prepended to IOHID event data (28 bytes).
/// Contains metadata about the event batch.
private struct IOHIDSystemQueueElementHeader {
    var timestamp: UInt64         // Mach absolute time
    var senderID: UInt64          // Sender identifier (can be 0)
    var options: UInt32           // Options flags (usually 0)
    var attributeLength: UInt32   // Length of attributes (usually 0)
    var eventCount: UInt32        // Number of events: 1 (gesture only) or 2 (gesture + velocity)
}

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
    // Additional fields for macOS 27 (from joshuarli/iss)
    fileprivate static let swipeMask = CGEventField(rawValue: 115)!
    fileprivate static let swipePositionX = CGEventField(rawValue: 125)!
    fileprivate static let swipePositionY = CGEventField(rawValue: 126)!
    fileprivate static let gesturePhase2 = CGEventField(rawValue: 134)!
    fileprivate static let gestureFlavor = CGEventField(rawValue: 138)!
    fileprivate static let eventTimestamp = CGEventField(rawValue: 169)!
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
    // Max ~32000 to avoid Int32 overflow in 16.16 fixed-point conversion for IOHID payload
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
/// On macOS 27+, augments events with the required IOHID payload.
struct SystemEventPoster: EventPosting {

    // MARK: - IOHID Constants (from joshuarli/iss)

    private static let kIOHIDEventTypeVelocity: UInt32 = 9
    private static let kIOHIDEventTypeFluidTouchGesture: UInt32 = 23
    private static let kIOHIDGestureFlavorDockPrimary: UInt16 = 3

    // MARK: - macOS Version Detection

    /// True if running macOS 27+, which requires IOHID payload augmentation.
    private static let requiresAugmentation: Bool = {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }()

    // MARK: - EventPosting

    func postDockSwipe(
        phase: Int64, goRight: Bool, velocity: Double
    ) {
        let progress = goRight ? 1.0 : -1.0
        let vel = goRight ? velocity : -velocity

        guard let event = CGEvent(source: nil) else { return }

        // Standard gesture fields (work on all macOS versions)
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
            GestureSwitcher.swipeVelocityY, value: 0)

        // Additional fields for macOS 27 (from joshuarli/iss)
        event.setIntegerValueField(GestureSwitcher.gesturePhase2, value: phase)
        event.setDoubleValueField(GestureSwitcher.gestureFlavor, value: 3.0)
        event.setDoubleValueField(
            GestureSwitcher.eventTimestamp,
            value: Double(mach_absolute_time()))
        event.setDoubleValueField(GestureSwitcher.swipePositionX, value: 0.1)

        if Self.requiresAugmentation {
            postAugmentedEvent(event, phase: phase, velocity: vel)
        } else {
            event.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - macOS 27 Event Augmentation

    /// Posts a CGEvent augmented with the IOHID payload required by macOS 27.
    ///
    /// macOS 27 validates synthetic dock-swipe events against a serialized IOHID
    /// queue element in CGEvent field 4205. This method:
    /// 1. Serializes the event to bytes via CGEventCreateData()
    /// 2. Builds an IOHIDSystemQueueElement with gesture/velocity data
    /// 3. Appends it with the Field 4205 tag format
    /// 4. Deserializes back via CGEventCreateFromData()
    ///
    /// Falls back to posting the original event if serialization fails.
    private func postAugmentedEvent(_ event: CGEvent, phase: Int64, velocity: Double) {
        // Step 1: Serialize the CGEvent to bytes
        guard let serializedData = event.data else {
            event.post(tap: .cgSessionEventTap)
            return
        }

        // Step 2: Build the IOHIDSystemQueueElement payload
        // Contains: header (28 bytes) + gesture data (40 bytes) + optional velocity (28 bytes)
        let payload = buildIOHIDPayload(event: event, phase: phase, velocity: velocity)

        // Step 3: Append Field 4205 tag + payload to serialized event
        // Tag format (big-endian): [size_hi][size_lo][0x10][0x6D][payload...]
        var bytes = Data(referencing: serializedData)
        appendField4205(to: &bytes, payload: payload)

        // Step 4: Deserialize back to CGEvent and post
        if let augmented = CGEvent(withDataAllocator: kCFAllocatorDefault, data: bytes as CFData) {
            augmented.post(tap: .cgSessionEventTap)
        } else {
            // Fallback: post original (won't work on macOS 27, but better than nothing)
            event.post(tap: .cgSessionEventTap)
        }
    }

    /// Builds the IOHIDSystemQueueElement payload for field 4205.
    /// Structure: Header (28 bytes) + FluidTouchGestureData (40 bytes) + VelocityData (28 bytes)
    private func buildIOHIDPayload(event: CGEvent, phase: Int64, velocity: Double) -> Data {
        let timestamp = event.timestamp != 0 ? event.timestamp : mach_absolute_time()
        let progress = event.getDoubleValueField(GestureSwitcher.swipeProgress)
        let posX = event.getDoubleValueField(GestureSwitcher.swipePositionX)
        let posY = event.getDoubleValueField(GestureSwitcher.swipePositionY)

        // Always include velocity event (required for reliable switching)
        let eventCount: UInt32 = 2

        var data = Data()

        // Header (28 bytes)
        var header = IOHIDSystemQueueElementHeader(
            timestamp: timestamp,
            senderID: 0,
            options: 0,
            attributeLength: 0,
            eventCount: eventCount
        )
        withUnsafeBytes(of: &header) { data.append(contentsOf: $0) }

        // FluidTouchGestureData (40 bytes)
        var gesture = IOHIDFluidTouchGestureData(
            base: IOHIDEventBase(
                size: UInt32(MemoryLayout<IOHIDFluidTouchGestureData>.size),
                type: Self.kIOHIDEventTypeFluidTouchGesture,
                options: UInt32((phase & 0xFF) << 24),
                depth: 0,
                reserved: (0, 0, 0)
            ),
            positionX: toFixedPoint(posX),
            positionY: toFixedPoint(posY),
            positionZ: 0,
            swipeMask: 0,
            gestureMotion: 1,  // horizontal
            gestureFlavor: Self.kIOHIDGestureFlavorDockPrimary,
            // IOHID convention: negative progress = going right (opposite of CGEvent)
            swipeProgress: toFixedPoint(-progress)
        )
        withUnsafeBytes(of: &gesture) { data.append(contentsOf: $0) }

        // VelocityEventData (28 bytes)
        var velocityEvent = IOHIDVelocityEventData(
            base: IOHIDEventBase(
                size: UInt32(MemoryLayout<IOHIDVelocityEventData>.size),
                type: Self.kIOHIDEventTypeVelocity,
                options: 0,
                depth: 1,  // child of gesture event
                reserved: (0, 0, 0)
            ),
            // IOHID convention: negative velocity = going right (opposite of CGEvent)
            velocityX: toFixedPoint(-velocity),
            velocityY: 0,
            velocityZ: 0
        )
        withUnsafeBytes(of: &velocityEvent) { data.append(contentsOf: $0) }

        return data
    }

    /// Converts a Double to 16.16 fixed-point format.
    /// The integer part occupies the upper 16 bits, fractional part the lower 16.
    /// Clamps to Int32 range to prevent overflow crashes with large velocity values.
    /// Note: speedInstant must stay below ~32000 to avoid overflow (32000 * 65536 ≈ Int32.max).
    private func toFixedPoint(_ value: Double) -> Int32 {
        let scaled = value * 65536.0
        // Clamp to Int32 range to prevent overflow
        if scaled >= Double(Int32.max) {
            return Int32.max
        }
        if scaled <= Double(Int32.min) {
            return Int32.min
        }
        let fixed = Int32(scaled)
        // Prevent truncation to zero for very small non-zero values
        if fixed == 0 && value != 0.0 {
            return value > 0 ? 1 : -1
        }
        return fixed
    }

    /// Appends payload to serialized CGEvent bytes with Field 4205 tag.
    /// Tag format (big-endian): [size_hi][size_lo][field_hi][field_lo][payload...]
    /// Field 4205 = 0x106D
    private func appendField4205(to bytes: inout Data, payload: Data) {
        let size = UInt16(payload.count)
        bytes.append(UInt8(size >> 8))        // size high byte
        bytes.append(UInt8(size & 0xFF))      // size low byte
        bytes.append(0x10)                    // 4205 >> 8
        bytes.append(0x6D)                    // 4205 & 0xFF
        bytes.append(payload)
    }
}
