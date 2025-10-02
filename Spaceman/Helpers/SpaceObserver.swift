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
    
    private func getDisplayX(display: NSDictionary) -> CGFloat {
        guard let uuidString = display["Display Identifier"] as? String else {
            return 0
        }
        let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, uuidString as CFString)
        let dId = CGDisplayGetDisplayIDFromUUID(uuid)
        let bounds = CGDisplayBounds(dId)
        return bounds.origin.x
    }
    
    @objc public func updateSpaceInformation() {
        let restartByDesktop = defaults.bool(forKey: "restartNumberingByDesktop")
        let reverseDisplayOrder = defaults.bool(forKey: "reverseDisplayOrder")
        workerQueue.async { [weak self] in
            self?.performSpaceInformationUpdate(restartByDesktop: restartByDesktop, reverseDisplayOrder: reverseDisplayOrder)
        }
    }

    private func performSpaceInformationUpdate(restartByDesktop: Bool, reverseDisplayOrder: Bool) {
        guard var displays = fetchDisplaySpaces() else { return }

        let spaceNumberMap = buildSpaceNumberMap(from: displays)

        // Sort displays by X position (left to right), then invert if requested
        displays.sort { getDisplayX(display: $0) < getDisplayX(display: $1) }
        if reverseDisplayOrder {
            displays.reverse()
        }

        let storedNames = nameStore.loadAll()
        var updatedNames = storedNames
        var lastSpaceByDesktopNumber = 0
        var collectedSpaces: [Space] = []

        for (displayIndex, display) in displays.enumerated() {
            guard
                let currentSpace = display["Current Space"] as? [String: Any],
                let spaces = display["Spaces"] as? [[String: Any]],
                let displayID = display["Display Identifier"] as? String,
                let activeID = currentSpace["ManagedSpaceID"] as? Int
            else {
                continue
            }

            if restartByDesktop {
                lastSpaceByDesktopNumber = 0
            }

            var lastFullScreenSpaceNumber = 0
            var positionOnThisDisplay = 0

            for spaceDict in spaces {
                guard let managedInt = spaceDict["ManagedSpaceID"] as? Int else { continue }
                let managedSpaceID = String(managedInt)
                guard let spaceNumber = spaceNumberMap[managedSpaceID] else { continue }

                let isCurrentSpace = activeID == managedInt
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
                if restartByDesktop {
                    currentSpaceNumber = positionOnThisDisplay
                } else {
                    currentSpaceNumber = spaceNumber
                }

                var nameInfo = SpaceNameInfo(
                    spaceNum: spaceNumber,
                    spaceName: resolvedName,
                    spaceByDesktopID: spaceByDesktopID)

                // Populate new fields
                nameInfo.displayUUID = displayID
                nameInfo.positionOnDisplay = positionOnThisDisplay
                nameInfo.currentDisplayIndex = displayIndex + 1  // 1-based index
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
