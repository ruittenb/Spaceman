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

        for d in displays {
            guard let currentSpaces = d["Current Space"] as? [String: Any],
                  let spaces = d["Spaces"] as? [[String: Any]],
                  let displayID = d["Display Identifier"] as? String
            else {
                continue
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

                // Try to find saved name, verifying position to handle ManagedSpaceID swaps after reboot.
                // Always search in storedNames (pre-update snapshot) to avoid issues with in-flight modifications.
                let savedInfo = SpaceObserver.resolveSpaceNameInfo(
                    managedSpaceID: managedSpaceID,
                    displayID: displayID,
                    position: positionOnThisDisplay,
                    storedNames: storedNames)
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

    /// Finds a space by display UUID and position.
    static func findSpaceByPosition(
        in storedNames: [String: SpaceNameInfo],
        displayID: String,
        position: Int
    ) -> SpaceNameInfo? {
        storedNames.values.first { $0.displayUUID == displayID && $0.positionOnDisplay == position }
    }

    /// Resolves the saved SpaceNameInfo for a space, handling ManagedSpaceID swaps after reboot.
    /// First tries to match by ManagedSpaceID with position verification, then falls back to position-only lookup.
    static func resolveSpaceNameInfo(
        managedSpaceID: String,
        displayID: String,
        position: Int,
        storedNames: [String: SpaceNameInfo]
    ) -> SpaceNameInfo? {
        // Try by ManagedSpaceID first, but only accept if position matches
        if let info = storedNames[managedSpaceID],
           info.displayUUID == displayID,
           info.positionOnDisplay == position {
            return info
        }
        // Fall back to position-based lookup
        return findSpaceByPosition(in: storedNames, displayID: displayID, position: position)
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
        return "-"
    }
}

protocol SpaceObserverDelegate: AnyObject {
    func didUpdateSpaces(spaces: [Space])
}
