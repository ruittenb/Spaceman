//
//  SpaceObserver.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Cocoa
import Foundation

class SpaceObserver {
    private let workspace = NSWorkspace.shared
    private let conn = _CGSDefaultConnection()
    private let defaults = UserDefaults.standard
    private let nameStore = SpaceNameStore.shared
    private let workerQueue = DispatchQueue(label: "dev.ruittenb.Spaceman.SpaceObserver")

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
        workerQueue.async { [weak self] in
            self?.performSpaceInformationUpdate(restartNumberingByDisplay: restartNumberingByDisplay, horizontalDirection: horizontalDirection, verticalDirection: verticalDirection)
        }
    }

    private func performSpaceInformationUpdate(restartNumberingByDisplay: Bool, horizontalDirection: HorizontalDirection, verticalDirection: VerticalDirection) {
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

        // Build space number map AFTER sorting to ensure numbering matches display order
        let spaceNumberMap = buildSpaceNumberMap(from: displays)

        let storedNames = nameStore.loadAll()
        var updatedNames: [String: SpaceNameInfo] = [:]
        var activeSpaceID = -1
        var lastSpaceByDesktopNumber = 0
        var collectedSpaces: [Space] = []

        // Step 1: Collect current space IDs per display (see MARK: Space Name Resolution)
        var currentIDsByDisplay: [String: Set<String>] = [:]
        for d in displays {
            guard let spaces = d["Spaces"] as? [[String: Any]],
                  let displayID = d["Display Identifier"] as? String
            else { continue }
            var ids = Set<String>()
            for spaceDict in spaces {
                if let managedInt = spaceDict["ManagedSpaceID"] as? Int {
                    ids.insert(String(managedInt))
                }
            }
            currentIDsByDisplay[displayID] = ids
        }

        // Step 2: Process displays and resolve space names
        for d in displays {
            guard let currentSpaces = d["Current Space"] as? [String: Any],
                  let spaces = d["Spaces"] as? [[String: Any]],
                  let displayID = d["Display Identifier"] as? String
            else {
                continue
            }

            // Step 3: Determine matching strategy for this display
            let currentIDs = currentIDsByDisplay[displayID] ?? []
            let usePositionMatching = !SpaceObserver.idsMatchStored(
                currentIDs: currentIDs,
                storedNames: storedNames,
                displayID: displayID
            )

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

                // Resolve saved name using appropriate strategy for this display
                let savedInfo = SpaceObserver.resolveSpaceNameInfo(
                    managedSpaceID: managedSpaceID,
                    displayID: displayID,
                    position: positionOnThisDisplay,
                    storedNames: storedNames,
                    usePositionMatching: usePositionMatching)
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

                nameInfo.displayUUID = displayID
                nameInfo.positionOnDisplay = positionOnThisDisplay
                nameInfo.currentDisplayIndex = currentDisplayIndexByID[displayID]
                nameInfo.currentSpaceNumber = currentSpaceNumber
                nameInfo.colorHex = savedInfo?.colorHex

                updatedNames[managedSpaceID] = nameInfo
                collectedSpaces.append(space)
            }
        }

        if updatedNames != storedNames {
            nameStore.save(updatedNames)
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

    // MARK: - Space Name Resolution
    //
    // These methods handle matching spaces to their stored names/colors. Two scenarios
    // look similar but require opposite handling:
    //
    // 1. REBOOT SCENARIO: After a system reboot, macOS may assign different ManagedSpaceIDs
    //    to the same physical spaces. The user's custom names should stay at their original
    //    positions. We detect this when the set of current IDs differs from stored IDs.
    //    Solution: Match by position (usePositionMatching = true).
    //
    // 2. USER REORDER SCENARIO: When the user drags spaces in Mission Control to reorder them,
    //    the ManagedSpaceIDs stay the same but positions change. The names/colors should
    //    follow the space, not stay locked to positions. We detect this when IDs match.
    //    Solution: Match by ID (usePositionMatching = false).
    //
    // The key insight: if IDs changed, it's a reboot; if IDs are the same, user reordered.
    // Detection is done per-display since displays are independent.
    //
    // Algorithm in performSpaceInformationUpdate:
    //   Step 1: Collect current space IDs per display
    //   Step 2: For each display, compare IDs with stored IDs to choose matching strategy
    //   Step 3: Resolve each space's name using the chosen strategy

    /// Finds a stored space entry by display UUID and position.
    static func findSpaceByPosition(
        in storedNames: [String: SpaceNameInfo],
        displayID: String,
        position: Int
    ) -> SpaceNameInfo? {
        storedNames.values.first { $0.displayUUID == displayID && $0.positionOnDisplay == position }
    }

    /// Checks if current space IDs for a display exactly match stored IDs.
    /// Returns true if IDs match (use ID-based matching), false if they differ (use position-based).
    static func idsMatchStored(
        currentIDs: Set<String>,
        storedNames: [String: SpaceNameInfo],
        displayID: String
    ) -> Bool {
        let storedIDsForDisplay = Set(
            storedNames
                .filter { $0.value.displayUUID == displayID }
                .keys
        )
        return currentIDs == storedIDsForDisplay
    }

    /// Resolves the saved SpaceNameInfo for a space using the appropriate matching strategy.
    static func resolveSpaceNameInfo(
        managedSpaceID: String,
        displayID: String,
        position: Int,
        storedNames: [String: SpaceNameInfo],
        usePositionMatching: Bool
    ) -> SpaceNameInfo? {
        if usePositionMatching {
            return findSpaceByPosition(in: storedNames, displayID: displayID, position: position)
        } else {
            return storedNames[managedSpaceID]
        }
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
