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
        let c1 = getDisplayCenter(display: d1)
        let c2 = getDisplayCenter(display: d2)
        let tolerance: CGFloat = 2
        let cmpX: (CGPoint, CGPoint) -> Bool = { a, b in
            return a.x < b.x
        }
        let cmpY: (CGPoint, CGPoint) -> Bool = { a, b in
            // macOS global coordinates origin at bottom-left; larger y is higher
            switch verticalDirection {
            case .macOSOrder: return a.x < b.x
            case .topGoesRight: return a.y > b.y
            case .topGoesLeft: return a.y < b.y
            }
        }
        //switch displayOrderPriority {
        //case .horizontal:
        //    if abs(c1.x - c2.x) > tolerance { return cmpX(c1, c2) }
            return cmpY(c1, c2)
        //case .vertical:
        //    if abs(c1.y - c2.y) > tolerance { return cmpY(c1, c2) }
        //    return cmpX(c1, c2)
        //}
    }

    func getDisplayCenter(display: NSDictionary) -> CGPoint {
        guard let uuidString = display["Display Identifier"] as? String else { return .zero }
        let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, uuidString as CFString)
        let did = CGDisplayGetDisplayIDFromUUID(uuid)
        // Prefer NSScreen frame for consistent origin handling
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               CGDirectDisplayID(num.uint32Value) == did {
                let f = screen.frame
                return CGPoint(x: f.origin.x + f.size.width/2, y: f.origin.y + f.size.height/2)
            }
        }
        let b = CGDisplayBounds(did)
        return CGPoint(x: b.origin.x + b.size.width/2, y: b.origin.y + b.size.height/2)
    }

    @objc public func updateSpaceInformation() {
        let restartNumberingByDisplay = defaults.bool(forKey: "restartNumberingByDisplay")
        let reverseDisplayOrder = defaults.bool(forKey: "reverseDisplayOrder")
        let verticalDirection = VerticalDirection(rawValue: defaults.integer(forKey: "verticalDirection")) ?? .topGoesRight
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
