//
//  WindowMover.swift
//  Spaceman
//
//  Moves the focused window with the native macOS interaction: begin dragging
//  its title, invoke the Mission Control left/right shortcut, then release it.
//

import ApplicationServices
import AppKit

enum WindowMoveDirection: Equatable {
    case previous
    case next
}

enum WindowMoveError: LocalizedError {
    case accessibilityPermissionRequired
    case missionControlShortcutMissing(WindowMoveDirection)
    case noFocusedWindow
    case eventCreationFailed
    case spaceDidNotChange

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return String(localized: "Grant Accessibility access to Spaceman to move windows between spaces.")
        case .missionControlShortcutMissing(let direction):
            let name = direction == .previous ? "Move left a space" : "Move right a space"
            return String(localized: "Enable the ‘\(name)’ shortcut in Mission Control settings.")
        case .noFocusedWindow:
            return String(localized: "No movable focused window was found.")
        case .eventCreationFailed:
            return String(localized: "Spaceman could not create the input events needed to move the window.")
        case .spaceDidNotChange:
            return String(localized: "The adjacent space could not be reached.")
        }
    }

    var canOpenRelevantSettings: Bool {
        switch self {
        case .accessibilityPermissionRequired, .missionControlShortcutMissing:
            return true
        default:
            return false
        }
    }

    var settingsURL: URL? {
        switch self {
        case .accessibilityPermissionRequired:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .missionControlShortcutMissing:
            return URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")
        default:
            return nil
        }
    }
}

final class WindowMover {
    private enum ITermDrag {
        static let bundleIdentifierPrefix = "com.googlecode.iterm2"
        static let grabOffset: CGFloat = 2
        static let distance: CGFloat = 10
        static let stepCount = 3
        static let startDelay = 0.05
        static let stepInterval = 0.07
        static let shortcutDelay = 0.05
    }

    private struct FocusedWindow {
        let element: AXUIElement
        let originalPosition: CGPoint
        let grabPoint: CGPoint
        let needsActivationDrag: Bool
    }

    private struct ActiveMove {
        let id: UUID
        let window: FocusedWindow
        let releasePoint: CGPoint
        let source: CGEventSource
        let onError: (WindowMoveError) -> Void
    }

    private let shortcutHelper: ShortcutHelper
    private var activeMove: ActiveMove?
    private var spaceChangeObserver: NSObjectProtocol?
    private var timeoutWorkItem: DispatchWorkItem?

    init(shortcutHelper: ShortcutHelper = ShortcutHelper()) {
        self.shortcutHelper = shortcutHelper
    }

    func move(
        _ direction: WindowMoveDirection,
        onError: @escaping (WindowMoveError) -> Void
    ) {
        guard activeMove == nil else {
            return
        }
        guard AXIsProcessTrusted() else {
            onError(.accessibilityPermissionRequired)
            return
        }

        shortcutHelper.reload()
        guard let shortcut = shortcut(for: direction) else {
            onError(.missionControlShortcutMissing(direction))
            return
        }
        guard let window = focusedWindow() else {
            onError(.noFocusedWindow)
            return
        }
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            onError(.eventCreationFailed)
            return
        }

        source.localEventsSuppressionInterval = 0
        let moveID = UUID()
        let activationDragPoints = Self.activationDragPoints(
            from: window.grabPoint,
            enabled: window.needsActivationDrag)
        let releasePoint = activationDragPoints.last ?? window.grabPoint
        activeMove = ActiveMove(
            id: moveID,
            window: window,
            releasePoint: releasePoint,
            source: source,
            onError: onError)

        guard postMouseEvent(.mouseMoved, at: window.grabPoint, source: source) else {
            finishMove(error: .eventCreationFailed)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self, self.activeMove?.id == moveID else { return }
            guard self.postMouseEvent(.leftMouseDown, at: window.grabPoint, source: source) else {
                self.finishMove(error: .eventCreationFailed)
                return
            }
        }

        for (index, point) in activationDragPoints.enumerated() {
            let delay = ITermDrag.startDelay + Double(index) * ITermDrag.stepInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.activeMove?.id == moveID else { return }
                guard self.postMouseEvent(.leftMouseDragged, at: point, source: source) else {
                    self.finishMove(error: .eventCreationFailed)
                    return
                }
            }
        }

        let shortcutDelay = activationDragPoints.isEmpty
            ? 0.1
            : ITermDrag.startDelay
                + Double(activationDragPoints.count) * ITermDrag.stepInterval
                + ITermDrag.shortcutDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + shortcutDelay) { [weak self] in
            guard let self, self.activeMove?.id == moveID else { return }
            self.observeSpaceChange()
            self.scheduleTimeout()
            guard self.postShortcut(shortcut, source: source) else {
                self.finishMove(error: .eventCreationFailed)
                return
            }
        }
    }

    func cancelMove() {
        finishMove(error: nil)
    }

    private static func grabPoint(
        windowFrame: CGRect,
        needsActivationDrag: Bool = false
    ) -> CGPoint {
        let verticalOffset = needsActivationDrag ? ITermDrag.grabOffset : 3
        return CGPoint(x: windowFrame.midX, y: windowFrame.minY + verticalOffset)
    }

    static func needsActivationDrag(bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.hasPrefix(ITermDrag.bundleIdentifierPrefix) == true
    }

    static func hasAdjacentSpace(
        _ direction: WindowMoveDirection,
        from currentSpace: Space,
        in spaces: [Space]
    ) -> Bool {
        let displaySpaces = spaces
            .filter { $0.displayID == currentSpace.displayID }
            .sorted { $0.spaceNumber < $1.spaceNumber }
        guard let currentIndex = displaySpaces.firstIndex(where: {
            $0.spaceID == currentSpace.spaceID
        }) else { return false }

        switch direction {
        case .previous:
            return currentIndex > displaySpaces.startIndex
        case .next:
            return currentIndex < displaySpaces.index(before: displaySpaces.endIndex)
        }
    }

    private static func activationDragPoints(
        from startPoint: CGPoint,
        enabled: Bool
    ) -> [CGPoint] {
        guard enabled else { return [] }

        return (1...ITermDrag.stepCount).map { step in
            let progress = CGFloat(step) / CGFloat(ITermDrag.stepCount)
            return CGPoint(
                x: startPoint.x + ITermDrag.distance * progress,
                y: startPoint.y)
        }
    }

    private func shortcut(for direction: WindowMoveDirection) -> SpaceShortcut? {
        switch direction {
        case .previous:
            return shortcutHelper.moveLeftShortcut
        case .next:
            return shortcutHelper.moveRightShortcut
        }
    }

    private func focusedWindow() -> FocusedWindow? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = elementAttribute(
            kAXFocusedWindowAttribute as CFString,
            from: applicationElement),
              let position = pointAttribute(kAXPositionAttribute as CFString, from: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, from: window)
        else { return nil }

        let windowFrame = CGRect(origin: position, size: size)
        let needsActivationDrag = Self.needsActivationDrag(
            bundleIdentifier: application.bundleIdentifier)

        return FocusedWindow(
            element: window,
            originalPosition: position,
            grabPoint: Self.grabPoint(
                windowFrame: windowFrame,
                needsActivationDrag: needsActivationDrag),
            needsActivationDrag: needsActivationDrag)
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

    private func pointAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }

        var point = CGPoint.zero
        let axValue = unsafeBitCast(value, to: AXValue.self)
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }

        var size = CGSize.zero
        let axValue = unsafeBitCast(value, to: AXValue.self)
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func postMouseEvent(
        _ type: CGEventType,
        at point: CGPoint,
        source: CGEventSource
    ) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left)
        else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }

    private func postShortcut(
        _ shortcut: SpaceShortcut,
        source: CGEventSource
    ) -> Bool {
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(shortcut.keyCode),
            keyDown: true),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: false)
        else { return false }

        keyDown.flags = shortcut.eventFlags
        keyUp.flags = shortcut.eventFlags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func observeSpaceChange() {
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.activeMove != nil else { return }
            self.timeoutWorkItem?.cancel()
            self.removeSpaceChangeObserver()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.finishMove(error: nil)
            }
        }
    }

    private func scheduleTimeout() {
        let timeout = DispatchWorkItem { [weak self] in
            self?.finishMove(error: .spaceDidNotChange)
        }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
    }

    private func finishMove(error: WindowMoveError?) {
        guard let move = activeMove else { return }
        activeMove = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        removeSpaceChangeObserver()

        _ = postMouseEvent(.leftMouseUp, at: move.releasePoint, source: move.source)
        restoreWindowPosition(move.window.originalPosition, for: move.window.element)

        if let error {
            move.onError(error)
        }
    }

    private func restoreWindowPosition(
        _ position: CGPoint,
        for window: AXUIElement
    ) {
        var position = position
        guard let value = AXValueCreate(.cgPoint, &position) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private func removeSpaceChangeObserver() {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            spaceChangeObserver = nil
        }
    }
}
