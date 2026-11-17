//
//  SwitchCommands.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2026-11-17.
//  Co-author: Claude Code
//
//  AppleScript commands for switching spaces:
//
//    switch to space 3
//    switch to space "Mail"
//    switch to space 2 on display 2
//    switch to space "Mail" using instant
//    switch right / switch left / switch up / switch down / switch back
//

import Foundation
import Cocoa

// MARK: - Target resolution (pure, testable)

enum ScriptSpaceResolver {

    /// Find the space a script refers to.
    /// - Parameters:
    ///   - spaces: all spaces, in menu order
    ///   - displayIDs: display UUIDs in display order (display 1 first)
    ///   - number: without `displayNumber`, the global space number (as `current space number`);
    ///     with `displayNumber`, the position of the space on that display (1-based)
    ///   - name: the space name, compared case-insensitively; the first match wins
    ///   - displayNumber: restricts the search to this display (1-based)
    static func resolve(
        spaces: [Space], displayIDs: [String],
        number: Int?, name: String?, displayNumber: Int?
    ) -> Space? {
        var candidates = spaces
        if let displayNumber {
            guard displayNumber >= 1, displayNumber <= displayIDs.count else { return nil }
            let displayID = displayIDs[displayNumber - 1]
            candidates = spaces
                .filter { $0.displayID == displayID }
                .sorted { $0.spaceNumber < $1.spaceNumber }
        }
        if let number {
            if displayNumber != nil {
                guard number >= 1, number <= candidates.count else { return nil }
                return candidates[number - 1]
            }
            return candidates.first { $0.spaceNumber == number }
        }
        if let name {
            return candidates.first {
                $0.spaceName.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
        }
        return nil
    }

    // Enumerator codes of "switching mode" in Scriptable.sdef
    static let smoothCode = fourCharCode("Msmo")
    static let fastCode = fourCharCode("Mfst")
    static let instantCode = fourCharCode("Mins")

    static func switchingMode(fromEnumCode code: FourCharCode) -> SwitchingMode? {
        switch code {
        case smoothCode: return .smooth
        case fastCode: return .fast
        case instantCode: return .instant
        default: return nil
        }
    }

    static func fourCharCode(_ string: String) -> FourCharCode {
        string.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }
}

// MARK: - Base class

class SpacemanScriptCommand: NSScriptCommand {

    // Apple Event error numbers (MacErrors.h)
    static let coercionFailedError = -1700   // errAECoercionFail
    static let noSuchObjectError = -1728     // errAENoSuchObject
    static let eventFailedError = -10000     // errAEEventFailed

    /// The `using` parameter, or nil to use the switching mode preference.
    var requestedMode: SwitchingMode? {
        guard let code = evaluatedArguments?["mode"] as? NSNumber else { return nil }
        return ScriptSpaceResolver.switchingMode(fromEnumCode: code.uint32Value)
    }

    func fail(_ errorNumber: Int, _ message: String) -> Any? {
        scriptErrorNumber = errorNumber
        scriptErrorString = message
        return nil
    }

    func failNotReady() -> Any? {
        fail(Self.eventFailedError, String(localized: "Spaceman is not ready yet"))
    }
}

// MARK: - switch to space

class SwitchToSpaceCommand: SpacemanScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let appDelegate = AppDelegate.shared else { return failNotReady() }

        let number: Int?
        let name: String?
        let description: String
        if let text = directParameter as? String {
            number = nil
            name = text
            description = "\"\(text)\""
        } else if let value = directParameter as? NSNumber {
            number = value.intValue
            name = nil
            description = "\(value.intValue)"
        } else {
            return fail(Self.coercionFailedError, String(localized: "Expected a space number or name"))
        }
        let displayNumber = (evaluatedArguments?["display"] as? NSNumber)?.intValue

        guard let target = ScriptSpaceResolver.resolve(
            spaces: appDelegate.currentSpaces,
            displayIDs: appDelegate.orderedDisplayIDs(),
            number: number, name: name, displayNumber: displayNumber)
        else {
            return fail(Self.noSuchObjectError, String(localized: "Space not found: \(description)"))
        }
        if target.isCurrentSpace { return nil }

        if !appDelegate.scriptSwitch(to: target, mode: requestedMode) {
            return fail(Self.eventFailedError, String(localized: "Space cannot be reached: \(description)"))
        }
        return nil
    }
}

// MARK: - switch right / left / up / down / back

class DirectionalSwitchCommand: SpacemanScriptCommand {

    /// Perform the switch. Returns false when there is no space to switch to.
    func performSwitch(_ appDelegate: AppDelegate, mode: SwitchingMode?) -> Bool {
        false
    }

    var failureMessage: String {
        String(localized: "There is no space in that direction")
    }

    override func performDefaultImplementation() -> Any? {
        guard let appDelegate = AppDelegate.shared else { return failNotReady() }
        if !performSwitch(appDelegate, mode: requestedMode) {
            return fail(Self.eventFailedError, failureMessage)
        }
        return nil
    }
}

class SwitchRightCommand: DirectionalSwitchCommand {
    override func performSwitch(_ appDelegate: AppDelegate, mode: SwitchingMode?) -> Bool {
        appDelegate.scriptSwitchRelative(goRight: true, mode: mode)
    }
}

class SwitchLeftCommand: DirectionalSwitchCommand {
    override func performSwitch(_ appDelegate: AppDelegate, mode: SwitchingMode?) -> Bool {
        appDelegate.scriptSwitchRelative(goRight: false, mode: mode)
    }
}

class SwitchUpCommand: DirectionalSwitchCommand {
    override func performSwitch(_ appDelegate: AppDelegate, mode: SwitchingMode?) -> Bool {
        appDelegate.scriptSwitchVertical(direction: -1, mode: mode)
    }
}

class SwitchDownCommand: DirectionalSwitchCommand {
    override func performSwitch(_ appDelegate: AppDelegate, mode: SwitchingMode?) -> Bool {
        appDelegate.scriptSwitchVertical(direction: 1, mode: mode)
    }
}

class SwitchBackCommand: DirectionalSwitchCommand {
    override func performSwitch(_ appDelegate: AppDelegate, mode: SwitchingMode?) -> Bool {
        appDelegate.switchToPreviousSpace(mode: mode)
    }

    override var failureMessage: String {
        String(localized: "There is no previous space to switch to")
    }
}
