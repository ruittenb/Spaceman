//
//  MissionControlLabels.swift
//  Spaceman
//
//  Draws the user's space names over Mission Control's "Desktop 1", "Desktop 2"
//  captions.
//
//  Adapted from ActiveSpace (github.com/PerpetualBeta/ActiveSpace) with permission.
//  ActiveSpace itself credits MacSpaceLabeler (github.com/JohnSparham/MacSpaceLabeler)
//  for showing this approach on macOS 26.
//
//  On macOS 27+ the Spaces Bar lives in WindowManager (com.apple.WindowManager):
//
//      AXApplication "WindowManager"
//        AXGroup id=mc.display              one per display
//          AXGroup "Spaces Bar" id=mc.spaces
//            AXList id=mc.spaces.list
//              AXButton "Desktop 1" desc="exit to Desktop 1"   one per space
//
//  The Dock path is kept for macOS 26 and earlier.
//

import AppKit
import ApplicationServices

final class MissionControlLabels {

    private var timer: Timer?
    private var windows: [LabelWindow] = []
    private var apps: [String: (pid: pid_t, element: AXUIElement)] = [:]

    /// macOS 27 moved the Spaces Bar to WindowManager and left the Dock an empty stub.
    private static let spacesBarIsInDock =
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27
    private var wasOpen = false
    private var lastMismatch: String?

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "showMissionControlLabels")
    }

    /// Poll interval in seconds (default 250ms = 4x/second).
    private static var pollInterval: TimeInterval {
        let pollMs = UserDefaults.standard.object(forKey: "missionControlPollMs") as? Int ?? 250
        return TimeInterval(max(50, pollMs)) / 1000
    }

    /// Fraction of interval the poll may be late.
    private static let pollToleranceFraction = 0.2

    /// Timeout for AX calls to avoid blocking main thread.
    private static let axMessagingTimeout: Float = 0.1

    /// Offset from AX position (thumbnail center) to caption center.
    /// On macOS 27+, AX reports position as thumbnail center, not top-left.
    /// Caption sits 53pt below center (measured by ActiveSpace on macOS 27.0).
    private static var captionOffset: CGFloat {
        let offset = UserDefaults.standard.object(forKey: "missionControlCaptionOffset") as? Double
        return offset.map { CGFloat($0) } ?? 53
    }

    /// Gap between neighbouring labels.
    private static let labelGap: CGFloat = 4

    init() {
        // Listen for app terminations to clear cached AX elements
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[
                NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self?.apps = self?.apps.filter { $0.value.pid != app.processIdentifier } ?? [:]
        }

        // Listen for preference changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePreferenceChange()
        }

        // Start if already enabled
        if isEnabled {
            start()
        }
    }

    private func handlePreferenceChange() {
        if isEnabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard timer == nil else { return }
        let pollTimer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        pollTimer.tolerance = Self.pollInterval * Self.pollToleranceFraction
        RunLoop.main.add(pollTimer, forMode: .common)
        timer = pollTimer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        hideAll()
        wasOpen = false
    }

    // MARK: - Poll

    private struct Caption {
        let centre: CGPoint
        let maxWidth: CGFloat
        let covers: String
        let name: String
    }

    private func poll() {
        guard AXIsProcessTrusted() else { hideAll(); return }

        var captions: [Caption] = []
        var found = false

        // macOS 27+: WindowManager (but may also work on 26.5+)
        if let windowManager = appElement("com.apple.WindowManager") {
            let bars = spacesBars(in: windowManager, depthLimit: 2) {
                identifier(of: $0) == "mc.spaces"
            }
            found = !bars.isEmpty
            let mirror = bars.count == 1 && NSScreen.screens.count > 1 && Self.displaysShareSpaces()
            for bar in bars {
                captions += windowManagerCaptions(in: bar, mirrorToOtherScreens: mirror)
            }
        }

        // Fallback: Dock (macOS 26 and earlier)
        if !found, Self.spacesBarIsInDock, let dock = appElement("com.apple.dock"),
           let missionControl = children(of: dock).first(where: {
               title(of: $0) == "Mission Control"
           }) {
            let bars = spacesBars(in: missionControl, depthLimit: 3) {
                title(of: $0) == "Spaces Bar"
            }
            found = !bars.isEmpty
            for bar in bars {
                captions += dockCaptions(in: bar)
            }
        }

        if found != wasOpen {
            wasOpen = found
            lastMismatch = nil
        }
        if found {
            show(captions)
        } else {
            hideAll()
        }
    }

    private func appElement(_ bundleID: String) -> AXUIElement? {
        if let cached = apps[bundleID] { return cached.element }
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID).first else {
            apps[bundleID] = nil
            return nil
        }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, Self.axMessagingTimeout)
        apps[bundleID] = (app.processIdentifier, element)
        return element
    }

    private func spacesBars(in root: AXUIElement, depthLimit: Int,
                            matching isBar: (AXUIElement) -> Bool) -> [AXUIElement] {
        var found: [AXUIElement] = []
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth <= depthLimit else { return }
            for child in children(of: element) {
                if isBar(child) { found.append(child); continue }
                walk(child, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        return found
    }

    private func buttons(in bar: AXUIElement) -> [(frame: CGRect, title: String)] {
        for list in children(of: bar) {
            let found = children(of: list).compactMap { button -> (CGRect, String)? in
                guard let buttonFrame = frame(of: button) else { return nil }
                return (buttonFrame, title(of: button) ?? "")
            }
            if !found.isEmpty { return found }
        }
        return []
    }

    private func windowManagerCaptions(
        in bar: AXUIElement,
        mirrorToOtherScreens mirror: Bool
    ) -> [Caption] {
        let found = buttons(in: bar)
        if let first = found.first {
            print("MissionControlLabels: first button frame = \(first.frame)")
        }
        let centres = found.map {
            // macOS 27: AX position is thumbnail CENTER, not top-left
            // frame.minX/minY = center point
            // Caption sits below the visible thumbnail
            CGPoint(x: $0.frame.minX, y: $0.frame.minY + Self.captionOffset)
        }
        var captions = match(found, centres: centres, fallbackWidth: found.first?.frame.width ?? 0)

        guard mirror, let first = centres.first, let last = centres.last,
              let source = screen(containingAX: first) else { return captions }
        let layoutMid = (first.x + last.x) / 2
        for target in NSScreen.screens where target != source {
            let offsetX = axFrame(of: target).midX - layoutMid
            let offsetY = axFrame(of: target).minY - axFrame(of: source).minY
            let moved = centres.map { CGPoint(x: $0.x + offsetX, y: $0.y + offsetY) }
            captions += match(found, centres: moved, fallbackWidth: found.first?.frame.width ?? 0)
        }
        return captions
    }

    private static func displaysShareSpaces() -> Bool {
        let conn = _CGSDefaultConnection()
        guard let spacesRef = CGSCopyManagedDisplaySpaces(conn) else { return false }
        let spaces = spacesRef.takeRetainedValue() as? [[String: Any]]
        return spaces?.count == 1
    }

    private func screen(containingAX point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { axFrame(of: $0).contains(point) }
    }

    private func axFrame(of screen: NSScreen) -> CGRect {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        let screenFrame = screen.frame
        return CGRect(
            x: screenFrame.minX,
            y: primaryTop - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height)
    }

    private func dockCaptions(in bar: AXUIElement) -> [Caption] {
        let found = buttons(in: bar)
        let centres = found.map {
            // Dock: AX frame is top-left origin
            // Caption "Desktop N" sits below the frame
            // Spaces bar (small ~24pt high): caption ~15pt below frame
            // Thumbnails (~77pt high): caption ~8pt below frame
            let gapToCaption: CGFloat = $0.frame.height < 40 ? 18 : 8
            let captionY = $0.frame.maxY + gapToCaption + LabelWindow.height / 2
            return CGPoint(x: $0.frame.midX, y: captionY)
        }
        return match(found, centres: centres, fallbackWidth: found.first?.frame.width ?? 0)
    }

    /// Matches thumbnails to spaces and looks up names from SpaceNameStore.
    private func match(
        _ found: [(frame: CGRect, title: String)],
        centres: [CGPoint],
        fallbackWidth: CGFloat
    ) -> [Caption] {
        guard let first = centres.first else { return [] }
        let spaceIDs = orderedSpaceIDs(
            onScreenContaining: appKitRect(fromAX: CGRect(origin: first, size: .zero)))
        guard spaceIDs.count == found.count else {
            let message = "\(found.count) thumbnails but \(spaceIDs.count) spaces"
            if message != lastMismatch { lastMismatch = message }
            return []
        }

        let storedNames = SpaceNameStore.shared.loadAll()
        return centres.indices.compactMap { index in
            let spaceID = spaceIDs[index]
            guard let nameInfo = storedNames[spaceID], !nameInfo.spaceName.isEmpty else {
                return nil
            }
            let neighbours = [index - 1, index + 1]
                .filter(centres.indices.contains)
                .map { abs(centres[$0].x - centres[index].x) }
            let width = (neighbours.min() ?? fallbackWidth) - Self.labelGap
            return Caption(
                centre: centres[index],
                maxWidth: width,
                covers: found[index].title,
                name: nameInfo.spaceName)
        }
    }

    // MARK: - Spaces, in the order Mission Control shows them

    /// Returns ManagedSpaceIDs (as strings) for the display containing `rect`, in visual order.
    private func orderedSpaceIDs(onScreenContaining rect: CGRect) -> [String] {
        let conn = _CGSDefaultConnection()
        guard let spacesRef = CGSCopyManagedDisplaySpaces(conn) else { return [] }
        guard let displays = spacesRef.takeRetainedValue() as? [[String: Any]] else { return [] }

        let midpoint = CGPoint(x: rect.midX, y: rect.midY)
        let targetScreen = NSScreen.screens.first { $0.frame.contains(midpoint) }
        let screenUUID = targetScreen.flatMap { Self.displayUUID(of: $0) }

        let display = displays.count == 1
            ? displays.first
            : displays.first { ($0["Display Identifier"] as? String) == screenUUID }
        guard let display, let spaces = display["Spaces"] as? [[String: Any]] else { return [] }

        // Get UUIDs for visual order lookup
        let uuids = spaces.compactMap { $0["uuid"] as? String }
        let orderedUUIDs = Self.visualOrder(of: uuids)

        // Build UUID -> ManagedSpaceID map
        var uuidToID: [String: String] = [:]
        for space in spaces {
            if let uuid = space["uuid"] as? String,
               let managedSpaceID = space["ManagedSpaceID"] as? Int {
                uuidToID[uuid] = String(managedSpaceID)
            }
        }

        // Return ManagedSpaceIDs in visual order
        return orderedUUIDs.compactMap { uuidToID[$0] }
    }

    private static func displayUUID(of screen: NSScreen) -> String? {
        guard let screenNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(
            CGDirectDisplayID(screenNumber.uint32Value))?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    /// Reads the spaces plist to get visual order (left-to-right in Mission Control).
    private static func visualOrder(of uuids: [String]) -> [String] {
        let path = ("~/Library/Preferences/com.apple.spaces.plist" as NSString).expandingTildeInPath
        guard let plist = NSDictionary(contentsOfFile: path) as? [String: Any],
              let config = plist["SpacesDisplayConfiguration"] as? [String: Any],
              let management = config["Management Data"] as? [String: Any],
              let monitors = management["Monitors"] as? [[String: Any]] else { return uuids }

        let wanted = Set(uuids)
        var best: [String] = []
        for monitor in monitors {
            let spaces = monitor["Spaces"] as? [[String: Any]] ?? []
            let order = spaces.compactMap { $0["uuid"] as? String }
            if Set(order).intersection(wanted).count > Set(best).intersection(wanted).count {
                best = order
            }
        }
        return Set(best) == wanted && best.count == uuids.count ? best : uuids
    }

    // MARK: - Label windows

    private func show(_ captions: [Caption]) {
        while windows.count < captions.count { windows.append(LabelWindow()) }
        for (index, window) in windows.enumerated() {
            if index < captions.count {
                let caption = captions[index]
                window.place(
                    name: caption.name,
                    covering: caption.covers,
                    centredOn: appKitPoint(fromAX: caption.centre),
                    maxWidth: caption.maxWidth)
            } else if window.isVisible {
                window.orderOut(nil)
            }
        }
    }

    private func hideAll() {
        for window in windows where window.isVisible { window.orderOut(nil) }
    }

    private func appKitPoint(fromAX point: CGPoint) -> CGPoint {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: point.x, y: primaryTop - point.y)
    }

    private func appKitRect(fromAX rect: CGRect) -> CGRect {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(
            x: rect.minX,
            y: primaryTop - rect.maxY,
            width: rect.width,
            height: rect.height)
    }

    // MARK: - AX helpers

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &value) == .success
        else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXTitleAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func identifier(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXIdentifierAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(
            element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef,
              CFGetTypeID(posRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }
}

// MARK: - LabelWindow

/// A single name label drawn over one Mission Control caption. Click-through, on every space,
/// above Mission Control.
private final class LabelWindow: NSWindow {

    private let field = NSTextField(labelWithString: "")

    private static let padding = NSSize(width: 6, height: 2)
    private static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)

    static var height: CGFloat {
        ceil(font.ascender - font.descender + font.leading) + padding.height * 2
    }

    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let backing = NSView()
        backing.wantsLayer = true
        backing.layer?.backgroundColor = NSColor.black.cgColor
        backing.layer?.cornerRadius = 4
        contentView = backing

        field.font = Self.font
        field.textColor = .white
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        backing.addSubview(field)
    }

    func place(name: String, covering covers: String, centredOn centre: CGPoint, maxWidth: CGFloat) {
        field.stringValue = name
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.font]
        let nameWidth = field.intrinsicContentSize.width
        let fieldPadding = nameWidth - (name as NSString).size(withAttributes: attrs).width
        let coversWidth = (covers as NSString).size(withAttributes: attrs).width + fieldPadding
        let width = min(ceil(max(nameWidth, coversWidth)) + Self.padding.width * 2, maxWidth)
        let height = Self.height
        let windowFrame = CGRect(
            x: centre.x - width / 2,
            y: centre.y - height / 2,
            width: width,
            height: height)
        guard windowFrame != self.frame || !isVisible else {
            orderFrontRegardless()
            return
        }
        field.frame = CGRect(
            x: 0,
            y: Self.padding.height,
            width: width,
            height: height - Self.padding.height * 2)
        setFrame(windowFrame, display: true)
        orderFrontRegardless()
    }
}
