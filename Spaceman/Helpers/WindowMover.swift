//
//  WindowMover.swift
//  Spaceman
//
//  Moves the focused window to the adjacent space with SkyLight's bridged
//  window-management operation (SLSBridgedMoveWindowsToManagedSpaceOperation),
//  verifies that it landed, then follows it to the target space.
//

import ApplicationServices
import AppKit
import os

enum WindowMoveDirection: Equatable {
    case previous
    case next
}

enum WindowMoveError: LocalizedError, Equatable {
    case accessibilityPermissionRequired
    case noFocusedWindow
    case fullScreenWindow
    case windowOnMultipleSpaces
    case moveUnsupported
    case windowDidNotMove

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return String(localized: "Grant Accessibility access to Spaceman to move windows between spaces.")
        case .noFocusedWindow:
            return String(localized: "No movable focused window was found.")
        case .fullScreenWindow:
            return String(localized: "Full-screen windows can’t be moved to another space.")
        case .windowOnMultipleSpaces:
            return String(localized: "This window is shown on every space and can’t be moved.")
        case .moveUnsupported:
            return String(localized: "This version of macOS doesn’t let Spaceman move windows between spaces.")
        case .windowDidNotMove:
            return String(localized: "macOS didn’t move the window to the adjacent space.")
        }
    }

    var canOpenRelevantSettings: Bool {
        self == .accessibilityPermissionRequired
    }

    var settingsURL: URL? {
        guard self == .accessibilityPermissionRequired else { return nil }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
}

final class WindowMover {
    enum MoveResolution: Equatable {
        case move(source: Space, target: Space)
        case atEdge
        case failure(WindowMoveError)
    }

    private enum Timing {
        static let verifyInterval = 0.015
        static let verifyTimeout = 0.5
        static let followTimeout = 1.5
        static let raiseDelay = 0.15
    }

    /// CGSCopySpacesForWindows selector: current, other and user spaces.
    private static let allSpacesSelector: Int32 = 0x7

    private struct FocusedWindow {
        let element: AXUIElement
        let windowID: CGWindowID
        let processIdentifier: pid_t
    }

    private struct ActiveMove {
        let id: UUID
        let window: FocusedWindow
        let targetSpaceID: UInt64
        let onError: (WindowMoveError) -> Void
    }

    private static let log = Logger(subsystem: Constants.AppInfo.bundleId, category: "windowMove")

    private var activeMove: ActiveMove?
    private var spaceChangeObserver: NSObjectProtocol?
    private var timeoutWorkItem: DispatchWorkItem?

    func move(
        _ direction: WindowMoveDirection,
        spaces: [Space],
        switchToSpace: @escaping (String) -> Void,
        onError: @escaping (WindowMoveError) -> Void
    ) {
        guard activeMove == nil else {
            return
        }
        guard AXIsProcessTrusted() else {
            onError(.accessibilityPermissionRequired)
            return
        }
        guard let window = focusedWindow() else {
            onError(.noFocusedWindow)
            return
        }

        let resolution = Self.resolveMove(
            direction,
            windowSpaceIDs: Self.windowSpaceIDs(window.windowID),
            spaces: spaces)
        let targetSpace: Space
        switch resolution {
        case .atEdge:
            return
        case .failure(let error):
            onError(error)
            return
        case .move(_, let target):
            targetSpace = target
        }
        guard let targetSpaceID = UInt64(targetSpace.spaceID) else {
            onError(.windowDidNotMove)
            return
        }

        guard SkyLightBridge.move(windowID: window.windowID, toSpaceID: targetSpaceID) else {
            Self.log.error("Bridged move operation unavailable on \(Self.osVersion, privacy: .public)")
            onError(.moveUnsupported)
            return
        }

        let moveID = UUID()
        activeMove = ActiveMove(
            id: moveID,
            window: window,
            targetSpaceID: targetSpaceID,
            onError: onError)
        verifyMove(
            moveID: moveID,
            targetSpace: targetSpace,
            deadline: Date().addingTimeInterval(Timing.verifyTimeout),
            switchToSpace: switchToSpace)
    }

    func cancelMove() {
        finishMove(error: nil)
    }

    // MARK: - Space resolution

    static func hasAdjacentSpace(
        _ direction: WindowMoveDirection,
        from currentSpace: Space,
        in spaces: [Space]
    ) -> Bool {
        adjacentSpace(direction, from: currentSpace, in: spaces) != nil
    }

    /// The nearest non-full-screen space on the same display in the given direction.
    static func adjacentSpace(
        _ direction: WindowMoveDirection,
        from currentSpace: Space,
        in spaces: [Space]
    ) -> Space? {
        let displaySpaces = spaces
            .filter { $0.displayID == currentSpace.displayID }
            .sorted { $0.spaceNumber < $1.spaceNumber }
        guard let currentIndex = displaySpaces.firstIndex(where: {
            $0.spaceID == currentSpace.spaceID
        }) else { return nil }

        let candidates: [Space]
        switch direction {
        case .previous:
            candidates = Array(displaySpaces[..<currentIndex].reversed())
        case .next:
            candidates = Array(displaySpaces[(currentIndex + 1)...])
        }
        return candidates.first { !$0.isFullScreen }
    }

    /// Decides what to do with a window, given the spaces it is on.
    static func resolveMove(
        _ direction: WindowMoveDirection,
        windowSpaceIDs: [UInt64],
        spaces: [Space]
    ) -> MoveResolution {
        guard let sourceSpaceID = windowSpaceIDs.first else {
            return .failure(.noFocusedWindow)
        }
        guard windowSpaceIDs.count == 1 else {
            return .failure(.windowOnMultipleSpaces)
        }
        guard let source = spaces.first(where: { $0.spaceID == String(sourceSpaceID) }) else {
            return .failure(.noFocusedWindow)
        }
        guard !source.isFullScreen else {
            return .failure(.fullScreenWindow)
        }
        guard let target = adjacentSpace(direction, from: source, in: spaces) else {
            return .atEdge
        }
        return .move(source: source, target: target)
    }

    // MARK: - Moving, verifying and following

    private func verifyMove(
        moveID: UUID,
        targetSpace: Space,
        deadline: Date,
        switchToSpace: @escaping (String) -> Void
    ) {
        guard let move = activeMove, move.id == moveID else { return }

        if Self.windowSpaceIDs(move.window.windowID) == [move.targetSpaceID] {
            follow(moveID: moveID, targetSpace: targetSpace, switchToSpace: switchToSpace)
            return
        }
        guard Date() < deadline else {
            let windowID = move.window.windowID
            let spaceID = move.targetSpaceID
            Self.log.error("Window \(windowID) not moved to space \(spaceID) on \(Self.osVersion, privacy: .public)")
            finishMove(error: .windowDidNotMove)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.verifyInterval) { [weak self] in
            self?.verifyMove(
                moveID: moveID,
                targetSpace: targetSpace,
                deadline: deadline,
                switchToSpace: switchToSpace)
        }
    }

    private func follow(
        moveID: UUID,
        targetSpace: Space,
        switchToSpace: (String) -> Void
    ) {
        observeSpaceChange(moveID: moveID)
        scheduleFollowTimeout(moveID: moveID)
        switchToSpace(targetSpace.spaceID)
    }

    private func observeSpaceChange(moveID: UUID) {
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRaise(moveID: moveID)
        }
    }

    /// The window has already moved; if the switch never arrives, still bring the window forward.
    private func scheduleFollowTimeout(moveID: UUID) {
        let timeout = DispatchWorkItem { [weak self] in
            self?.scheduleRaise(moveID: moveID)
        }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.followTimeout, execute: timeout)
    }

    private func scheduleRaise(moveID: UUID) {
        guard activeMove?.id == moveID else { return }
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        removeSpaceChangeObserver()

        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.raiseDelay) { [weak self] in
            guard let self, let move = self.activeMove, move.id == moveID else { return }
            self.raise(move.window)
            self.finishMove(error: nil)
        }
    }

    private func raise(_ window: FocusedWindow) {
        let applicationElement = AXUIElementCreateApplication(window.processIdentifier)
        AXUIElementSetAttributeValue(applicationElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: window.processIdentifier)?.activate(options: [])
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    private func finishMove(error: WindowMoveError?) {
        guard let move = activeMove else { return }
        activeMove = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        removeSpaceChangeObserver()

        if let error {
            move.onError(error)
        }
    }

    private func removeSpaceChangeObserver() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
    }

    // MARK: - Window lookup

    private func focusedWindow() -> FocusedWindow? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = elementAttribute(
            kAXFocusedWindowAttribute as CFString,
            from: applicationElement)
        else { return nil }

        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else { return nil }

        return FocusedWindow(
            element: window,
            windowID: windowID,
            processIdentifier: application.processIdentifier)
    }

    private func elementAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func windowSpaceIDs(_ windowID: CGWindowID) -> [UInt64] {
        let windowList = [NSNumber(value: windowID)] as CFArray
        guard let spaceIDs = CGSCopySpacesForWindows(
            _CGSDefaultConnection(), allSpacesSelector, windowList)?
            .takeRetainedValue() as? [NSNumber]
        else { return [] }
        return spaceIDs.map { $0.uint64Value }
    }

    private static var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}

// MARK: - SkyLight bridged operation

/// Private SkyLight API, invoked through the Objective-C runtime (same approach as yabai, Loop, WhichSpace).
/// The operation is asynchronous and its result means nothing: callers must verify the move.
private enum SkyLightBridge {
    private static let objcMessageSend: UnsafeMutableRawPointer? = dlsym(
        dlopen(nil, RTLD_LAZY), "objc_msgSend")

    private typealias AllocateFunction = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
    private typealias InitializeFunction = @convention(c) (
        AnyObject, Selector, NSArray, UInt64) -> Unmanaged<AnyObject>?
    private typealias PerformFunction = @convention(c) (AnyObject, Selector) -> Void

    /// Returns false only when the private class or one of its selectors is missing.
    static func move(windowID: CGWindowID, toSpaceID spaceID: UInt64) -> Bool {
        guard let objcMessageSend,
              let operationClass = NSClassFromString(
                "SLSBridgedMoveWindowsToManagedSpaceOperation") as? NSObject.Type
        else { return false }

        let initializeSelector = NSSelectorFromString("initWithWindows:spaceID:")
        let performSelector = NSSelectorFromString("performWithWMBridgeDelegate")
        guard operationClass.instancesRespond(to: initializeSelector),
              operationClass.instancesRespond(to: performSelector)
        else { return false }

        let allocate = unsafeBitCast(objcMessageSend, to: AllocateFunction.self)
        let initialize = unsafeBitCast(objcMessageSend, to: InitializeFunction.self)
        let perform = unsafeBitCast(objcMessageSend, to: PerformFunction.self)

        // alloc returns +1, which init consumes; init returns +1, which we take.
        let windowIDs = [NSNumber(value: windowID)] as NSArray
        guard let allocated = allocate(operationClass, NSSelectorFromString("alloc")),
              let operation = initialize(
                allocated.takeUnretainedValue(), initializeSelector, windowIDs, spaceID)?
                .takeRetainedValue()
        else { return false }

        perform(operation, performSelector)
        return true
    }
}
