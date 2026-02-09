//
//  SpaceObserver.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Cocoa
import Foundation

/// Strategy for matching current spaces to stored name entries.
enum SpaceNameMatchingStrategy {
    /// Position-based matching only. Used after wake/reboot where macOS may
    /// swap ManagedSpaceIDs between spaces.
    case positionOnly

    /// Try ID matching first, fall back to position matching if the ID isn't found.
    /// Used when display topology changes — IDs are usually stable but some spaces
    /// may have received new IDs.
    case idWithPositionFallback

    /// ID-based matching only. Used during normal operation where IDs are stable
    /// and track user reorders correctly.
    case idOnly
}

class SpaceObserver {
    private let workspace = NSWorkspace.shared
    private let conn = _CGSDefaultConnection()
    private let defaults = UserDefaults.standard
    private let nameStore = SpaceNameStore.shared
    private let workerQueue = DispatchQueue(label: "dev.ruittenb.Spaceman.SpaceObserver")

    /// When true, the next update uses position-based matching to handle ID reassignment after reboot/wake.
    /// Starts true so the first update after app launch uses position matching.
    private var _needsPositionRevalidation = true

    /// Tracks the set of connected display UUIDs to detect topology changes (only accessed from workerQueue).
    private var _lastKnownDisplayIDs: Set<String> = []

    /// After a topology change, rapid follow-up updates may fire before macOS settles.
    /// This counter keeps `.idWithPositionFallback` active for several updates so that
    /// position preservation isn't defeated by a second update using `.idOnly`.
    /// Only accessed from workerQueue.
    private var _topologyChangeGracePeriod: Int = 0

    weak var delegate: SpaceObserverDelegate?

    init() {
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(updateSpaceInformation),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSpaceInformation),
            name: NSNotification.Name("ButtonPressed"),
            object: nil)
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    @objc private func handleWake() {
        _needsPositionRevalidation = true
    }

    @objc private func handleScreenChange() {
        updateSpaceInformation()
    }

    // Compare two displays according to user preferences
    func compareDisplays(d1: NSDictionary, d2: NSDictionary, verticalDirection: VerticalDirection, horizontalDirection: HorizontalDirection) -> Bool {
        let c1 = DisplayGeometryUtilities.getDisplayCenter(display: d1)
        let c2 = DisplayGeometryUtilities.getDisplayCenter(display: d2)
        let isVerticallyArranged = DisplayGeometryUtilities.getIsVerticallyArranged(d1: d1, d2: d2)

        return SpaceObserver.compareDisplayCenters(
            c1: c1,
            c2: c2,
            isVerticallyArranged: isVerticallyArranged,
            verticalDirection: verticalDirection,
            horizontalDirection: horizontalDirection
        )
    }

    // Compare two display centers according to user preferences (testable static method)
    static func compareDisplayCenters(
        c1: CGPoint,
        c2: CGPoint,
        isVerticallyArranged: Bool,
        verticalDirection: VerticalDirection,
        horizontalDirection: HorizontalDirection
    ) -> Bool {
        // Check if displays are vertically stacked
        if isVerticallyArranged {
            // Vertically stacked displays: use verticalDirection setting
            // macOS global coordinates origin at bottom-left; larger y is higher
            switch verticalDirection {
            case .defaultOrder:
                // macOS default: left-to-right by X coordinate
                return c1.x < c2.x
            case .topGoesFirst:
                // Top to bottom: higher Y goes first
                return c1.y > c2.y
            case .bottomGoesFirst:
                // Bottom to top: lower Y goes first
                return c1.y < c2.y
            }
        } else {
            // Side-by-side displays: use horizontalDirection setting
            switch horizontalDirection {
            case .defaultOrder:
                // Left to right
                return c1.x < c2.x
            case .reverseOrder:
                // Right to left
                return c1.x > c2.x
            }
        }
    }

    @objc public func updateSpaceInformation() {
        let restartNumberingByDisplay = defaults.bool(forKey: "restartNumberingByDisplay")
        let horizontalDirection = HorizontalDirection(rawValue: defaults.integer(forKey: "horizontalDirection")) ?? .defaultOrder
        let verticalDirection = VerticalDirection(rawValue: defaults.integer(forKey: "verticalDirection")) ?? .bottomGoesFirst
        let needsRevalidation = _needsPositionRevalidation
        _needsPositionRevalidation = false
        workerQueue.async { [weak self] in
            self?.performSpaceInformationUpdate(restartNumberingByDisplay: restartNumberingByDisplay, horizontalDirection: horizontalDirection, verticalDirection: verticalDirection, needsRevalidation: needsRevalidation)
        }
    }

    private func performSpaceInformationUpdate(restartNumberingByDisplay: Bool, horizontalDirection: HorizontalDirection, verticalDirection: VerticalDirection, needsRevalidation: Bool) {
        guard var displays = fetchDisplaySpaces() else { return }

        // Sort displays based on user preference (incorporating display ordering feature)
        displays.sort { a, b in compareDisplays(d1: a, d2: b, verticalDirection: verticalDirection, horizontalDirection: horizontalDirection) }

        // Map sorted display to index (1..D)
        var currentDisplayIndexByID: [String: Int] = [:]
        for (idx, d) in displays.enumerated() {
            if let displayID = d["Display Identifier"] as? String {
                currentDisplayIndexByID[displayID] = idx + 1
            }
        }

        // Collect connected display IDs
        let connectedDisplayIDs: Set<String> = Set(displays.compactMap { $0["Display Identifier"] as? String })

        // Detect display topology changes (e.g., close/open lid, mirror↔extend)
        let topologyChanged = !_lastKnownDisplayIDs.isEmpty && connectedDisplayIDs != _lastKnownDisplayIDs
        _lastKnownDisplayIDs = connectedDisplayIDs

        // After a topology change, keep topology-aware matching active for several
        // follow-up updates. macOS often fires multiple rapid notifications (e.g.,
        // didChangeScreenParameters + activeSpaceDidChange) and the second update
        // would otherwise use .idOnly, overwriting preserved positions.
        if topologyChanged {
            _topologyChangeGracePeriod = 5
        }
        let inTopologyTransition = topologyChanged || _topologyChangeGracePeriod > 0
        if _topologyChangeGracePeriod > 0 {
            _topologyChangeGracePeriod -= 1
        }

        // Build space number map AFTER sorting to ensure numbering matches display order
        let spaceNumberMap = buildSpaceNumberMap(from: displays)

        let storedNames = nameStore.loadAll()

        // Determine which stored display UUIDs have entries
        let storedDisplayIDs: Set<String> = Set(storedNames.values.compactMap { $0.displayUUID })

        var updatedNames: [String: SpaceNameInfo] = [:]
        var activeSpaceID = -1
        var lastSpaceByDesktopNumber = 0
        var collectedSpaces: [Space] = []

        for d in displays {
            guard let currentSpaces = d["Current Space"] as? [String: Any],
                  let spaces = d["Spaces"] as? [[String: Any]],
                  let displayID = d["Display Identifier"] as? String
            else {
                continue
            }

            // Per-display matching strategy:
            // - Wake/reboot: position matching to handle ID swaps
            // - Topology change or new display UUID: ID-first with position fallback
            //   (IDs usually stable through display changes, fallback handles new IDs)
            // - Normal operation: ID matching to track user reorders
            let strategy: SpaceNameMatchingStrategy
            if needsRevalidation {
                strategy = .positionOnly
            } else if inTopologyTransition || !storedDisplayIDs.contains(displayID) {
                strategy = .idWithPositionFallback
            } else {
                strategy = .idOnly
            }

            if restartNumberingByDisplay {
                lastSpaceByDesktopNumber = 0
            }

            var lastFullScreenSpaceNumber = 0
            var positionOnThisDisplay = 0
            let currentSpaceID = currentSpaces["ManagedSpaceID"] as? Int ?? -1
            if currentSpaceID != -1 && activeSpaceID == -1 {
                activeSpaceID = currentSpaceID
            }

            for spaceDict in spaces {
                guard let managedInt = spaceDict["ManagedSpaceID"] as? Int else { continue }
                let managedSpaceID = String(managedInt)
                guard let spaceNumber = spaceNumberMap[managedSpaceID] else { continue }

                let isCurrentSpace = currentSpaceID == managedInt
                let isFullScreen = spaceDict["TileLayoutManager"] as? [String: Any] != nil

                positionOnThisDisplay += 1

                let spaceByDesktopID: String
                if isFullScreen {
                    lastFullScreenSpaceNumber += 1
                    spaceByDesktopID = "F\(lastFullScreenSpaceNumber)"
                } else {
                    lastSpaceByDesktopNumber += 1
                    spaceByDesktopID = String(lastSpaceByDesktopNumber)
                }

                let savedInfo = SpaceObserver.resolveSpaceNameInfo(
                    managedSpaceID: managedSpaceID,
                    displayID: displayID,
                    position: positionOnThisDisplay,
                    storedNames: storedNames,
                    strategy: strategy,
                    connectedDisplayIDs: strategy != .idOnly ? connectedDisplayIDs : nil)
                let savedName = savedInfo?.spaceName
                let resolvedName = resolveSpaceName(
                    from: savedName,
                    spaceNumber: spaceNumber,
                    isFullScreen: isFullScreen,
                    spaceDict: spaceDict)

                let space = Space(
                    displayID: displayID,
                    spaceID: managedSpaceID,
                    spaceName: resolvedName,
                    spaceNumber: spaceNumber,
                    spaceByDesktopID: spaceByDesktopID,
                    isCurrentSpace: isCurrentSpace,
                    isFullScreen: isFullScreen,
                    colorHex: savedInfo?.colorHex)

                // Calculate currentSpaceNumber based on restart setting
                let currentSpaceNumber: Int
                if restartNumberingByDisplay {
                    currentSpaceNumber = positionOnThisDisplay
                } else {
                    currentSpaceNumber = spaceNumber
                }

                var nameInfo = SpaceNameInfo(
                    spaceNum: spaceNumber,
                    spaceName: resolvedName,
                    spaceByDesktopID: spaceByDesktopID)

                // During topology changes, if we found the entry by ID matching,
                // preserve its stored display/position. The current position is
                // transient (spaces migrated between displays) and would make
                // position-based recovery impossible if IDs change on the reverse
                // topology transition (issue #22b/#22c).
                let idMatchedDuringTopologyChange = strategy == .idWithPositionFallback
                    && storedNames[managedSpaceID] != nil
                if idMatchedDuringTopologyChange, let savedInfo = savedInfo {
                    nameInfo.displayUUID = savedInfo.displayUUID ?? displayID
                    nameInfo.positionOnDisplay = savedInfo.positionOnDisplay ?? positionOnThisDisplay
                } else {
                    nameInfo.displayUUID = displayID
                    nameInfo.positionOnDisplay = positionOnThisDisplay
                }
                nameInfo.currentDisplayIndex = currentDisplayIndexByID[displayID]
                nameInfo.currentSpaceNumber = currentSpaceNumber
                nameInfo.colorHex = savedInfo?.colorHex

                updatedNames[managedSpaceID] = nameInfo
                collectedSpaces.append(space)
            }
        }

        // Merge with stored names, preserving entries for disconnected displays
        let mergedNames = SpaceObserver.mergeSpaceNames(
            updatedNames: updatedNames,
            storedNames: storedNames,
            connectedDisplayIDs: connectedDisplayIDs)

        if mergedNames != storedNames {
            nameStore.save(mergedNames)
        }

        DispatchQueue.main.async {
            self.delegate?.didUpdateSpaces(spaces: collectedSpaces)
        }
    }

    private func fetchDisplaySpaces() -> [NSDictionary]? {
        guard let rawDisplays = CGSCopyManagedDisplaySpaces(conn)?.takeRetainedValue() as? [NSDictionary] else {
            return nil
        }
        return rawDisplays
    }

    private func buildSpaceNumberMap(from displays: [NSDictionary]) -> [String: Int] {
        var mapping: [String: Int] = [:]
        var index = 1
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                guard let managedID = space["ManagedSpaceID"] as? Int else { continue }
                mapping[String(managedID)] = index
                index += 1
            }
        }
        return mapping
    }

    /// Finds a space by display UUID and position, with optional fallback to disconnected displays.
    static func findSpaceByPosition(
        in storedNames: [String: SpaceNameInfo],
        displayID: String,
        position: Int,
        connectedDisplayIDs: Set<String>? = nil
    ) -> SpaceNameInfo? {
        // First try exact match by displayID + position
        if let match = storedNames.values.first(where: { $0.displayUUID == displayID && $0.positionOnDisplay == position }) {
            return match
        }
        // If connectedDisplayIDs provided, search entries from disconnected displays by position
        guard let connectedIDs = connectedDisplayIDs else { return nil }
        return storedNames.values.first { info in
            guard let uuid = info.displayUUID else { return false }
            return !connectedIDs.contains(uuid) && info.positionOnDisplay == position
        }
    }

    /// Resolves the saved SpaceNameInfo for a space using the given matching strategy.
    ///
    /// - `.positionOnly` (wake/reboot): match by position to handle ID swaps.
    /// - `.idWithPositionFallback` (topology change): try ID first, fall back to position for new IDs.
    /// - `.idOnly` (normal operation): match by ManagedSpaceID so user reorders are tracked.
    static func resolveSpaceNameInfo(
        managedSpaceID: String,
        displayID: String,
        position: Int,
        storedNames: [String: SpaceNameInfo],
        strategy: SpaceNameMatchingStrategy = .positionOnly,
        connectedDisplayIDs: Set<String>? = nil
    ) -> SpaceNameInfo? {
        switch strategy {
        case .positionOnly:
            return findSpaceByPosition(in: storedNames, displayID: displayID, position: position, connectedDisplayIDs: connectedDisplayIDs)
        case .idWithPositionFallback:
            if let idMatch = storedNames[managedSpaceID] {
                return idMatch
            }
            return findSpaceByPosition(in: storedNames, displayID: displayID, position: position, connectedDisplayIDs: connectedDisplayIDs)
        case .idOnly:
            return storedNames[managedSpaceID]
        }
    }

    /// Merges updated space names with stored names, preserving entries for
    /// disconnected displays and entries with user data whose ID was reassigned.
    static func mergeSpaceNames(
        updatedNames: [String: SpaceNameInfo],
        storedNames: [String: SpaceNameInfo],
        connectedDisplayIDs: Set<String>
    ) -> [String: SpaceNameInfo] {
        // Collect (displayUUID, position) pairs from updated entries so we can
        // detect when a stored entry's data has already migrated to a new key.
        let updatedPositions: Set<String> = Set(updatedNames.values.compactMap { info in
            guard let uuid = info.displayUUID, let pos = info.positionOnDisplay else { return nil }
            return "\(uuid):\(pos)"
        })

        var merged = updatedNames
        for (key, info) in storedNames {
            // Already in updatedNames under the same key — updated version wins.
            guard merged[key] == nil else { continue }
            guard let uuid = info.displayUUID else { continue }

            if !connectedDisplayIDs.contains(uuid) {
                // Disconnected display — always preserve.
                merged[key] = info
            } else if info.hasUserData {
                // Connected display, but this key wasn't seen in the current update
                // (macOS reassigned the ManagedSpaceID). Preserve ONLY if no updated
                // entry already occupies the same display+position slot — otherwise
                // the data has already migrated to the new key.
                let posKey = "\(uuid):\(info.positionOnDisplay ?? -1)"
                if !updatedPositions.contains(posKey) {
                    merged[key] = info
                }
            }
        }
        return merged
    }

    private func resolveSpaceName(
        from savedName: String?,
        spaceNumber: Int,
        isFullScreen: Bool,
        spaceDict: [String: Any]
    ) -> String {
        if let savedName, !savedName.isEmpty {
            return savedName
        }
        if isFullScreen {
            if let pid = spaceDict["pid"] as? pid_t,
               let app = NSRunningApplication(processIdentifier: pid),
               let name = app.localizedName {
                return name.uppercased()
            }
            return "FULL"
        }
        return ""
    }
}

protocol SpaceObserverDelegate: AnyObject {
    func didUpdateSpaces(spaces: [Space])
}
