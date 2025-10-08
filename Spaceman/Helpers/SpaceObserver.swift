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
    func compareDisplays(d1: NSDictionary, d2: NSDictionary, verticalDirection: VerticalDirection) -> Bool {
        let c1 = DisplayGeometryUtilities.getDisplayCenter(display: d1)
        let c2 = DisplayGeometryUtilities.getDisplayCenter(display: d2)

        let cmpX: (CGPoint, CGPoint) -> Bool = { a, b in
            return a.x < b.x
        }
        let cmpY: (CGPoint, CGPoint) -> Bool = { a, b in
            // macOS global coordinates origin at bottom-left; larger y is higher
            switch verticalDirection {
            case .defaultOrder: return a.x < b.x
            case .topGoesFirst: return a.y > b.y
            case .bottomGoesFirst: return a.y < b.y
            }
        }

        // If defaultOrder, always sort by X coordinate
        if verticalDirection == .defaultOrder {
            return cmpX(c1, c2)
        }

        // Check if displays are vertically stacked
        if DisplayGeometryUtilities.getIsVerticallyStacked(d1: d1, d2: d2) {
            return cmpY(c1, c2)
        } else {
            return cmpX(c1, c2)
        }
    }

    @objc public func updateSpaceInformation() {
        let restartNumberingByDisplay = defaults.bool(forKey: "restartNumberingByDisplay")
        let reverseDisplayOrder = defaults.bool(forKey: "reverseDisplayOrder")
        let verticalDirection = VerticalDirection(rawValue: defaults.integer(forKey: "verticalDirection")) ?? .bottomGoesFirst
        workerQueue.async { [weak self] in
            self?.performSpaceInformationUpdate(restartNumberingByDisplay: restartNumberingByDisplay, reverseDisplayOrder: reverseDisplayOrder, verticalDirection: verticalDirection)
        }
    }

    private func performSpaceInformationUpdate(restartNumberingByDisplay: Bool, reverseDisplayOrder: Bool, verticalDirection: VerticalDirection) {
        guard var displays = fetchDisplaySpaces() else { return }

        // Sort displays based on user preference (incorporating display ordering feature)
        displays.sort { a, b in compareDisplays(d1: a, d2: b, verticalDirection: verticalDirection) }

        // Reverse display order if requested
        if reverseDisplayOrder {
            displays.reverse()
        }

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
        var updatedNames = storedNames
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

                // Try to find saved name: first by managedSpaceID, then by position fallback
                var savedInfo = updatedNames[managedSpaceID]
                if savedInfo == nil {
                    // ManagedSpaceID may have changed (e.g., after reboot)
                    // Try to find by display + position
                    if let matchedInfo = findSpaceByPosition(
                        in: updatedNames,
                        displayID: displayID,
                        position: positionOnThisDisplay) {
                        savedInfo = matchedInfo
                        // Will update the key to the new managedSpaceID below
                    }
                }
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
                    isFullScreen: isFullScreen)

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

                // Populate additional fields from HEAD feature
                nameInfo.displayUUID = displayID
                nameInfo.positionOnDisplay = positionOnThisDisplay
                nameInfo.currentDisplayIndex = currentDisplayIndexByID[displayID]
                nameInfo.currentSpaceNumber = currentSpaceNumber

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

    private func findSpaceByPosition(
        in storedNames: [String: SpaceNameInfo],
        displayID: String,
        position: Int
    ) -> SpaceNameInfo? {
        // Find a space that matches both displayUUID and positionOnDisplay
        return storedNames.values.first { info in
            info.displayUUID == displayID && info.positionOnDisplay == position
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
        return "-"
    }
}

protocol SpaceObserverDelegate: AnyObject {
    func didUpdateSpaces(spaces: [Space])
}
