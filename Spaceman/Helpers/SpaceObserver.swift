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
    private let spaceNameCache = SpaceNameCache()
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
    
    func display1IsLeft(display1: NSDictionary, display2: NSDictionary) -> Bool {
        let d1Center = getDisplayCenter(display: display1)
        let d2Center = getDisplayCenter(display: display2)
        return d1Center.x < d2Center.x
    }
    
    func getDisplayCenter(display: NSDictionary) -> CGPoint {
        guard let uuidString = display["Display Identifier"] as? String
        else {
            return CGPoint(x: 0, y: 0)
        }
        let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, uuidString as CFString)
        let dId = CGDisplayGetDisplayIDFromUUID(uuid)
        let bounds = CGDisplayBounds(dId);
        return CGPoint(x: bounds.origin.x + bounds.size.width/2, y: bounds.origin.y + bounds.size.height/2)
    }
    
    @objc public func updateSpaceInformation() {
        let restartByDesktop = defaults.bool(forKey: "restartNumberingByDesktop")
        workerQueue.async { [weak self] in
            self?.performSpaceInformationUpdate(restartByDesktop: restartByDesktop)
        }
    }

    private func performSpaceInformationUpdate(restartByDesktop: Bool) {
        guard var displays = fetchDisplaySpaces() else { return }

        let spaceNumberMap = buildSpaceNumberMap(from: displays)
        displays.sort { display1IsLeft(display1: $0, display2: $1) }

        let storedNames = nameStore.loadAll()
        var updatedNames = storedNames
        let originalCache = spaceNameCache.snapshot()
        var cachedNames = originalCache
        var lastSpaceByDesktopNumber = 0
        var collectedSpaces: [Space] = []

        for display in displays {
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

            for spaceDict in spaces {
                guard let managedInt = spaceDict["ManagedSpaceID"] as? Int else { continue }
                let managedSpaceID = String(managedInt)
                guard let spaceNumber = spaceNumberMap[managedSpaceID] else { continue }

                let isCurrentSpace = activeID == managedInt
                let isFullScreen = spaceDict["TileLayoutManager"] as? [String: Any] != nil

                let spaceByDesktopID: String
                if isFullScreen {
                    lastFullScreenSpaceNumber += 1
                    spaceByDesktopID = "F\(lastFullScreenSpaceNumber)"
                } else {
                    lastSpaceByDesktopNumber += 1
                    spaceByDesktopID = String(lastSpaceByDesktopNumber)
                }


                spaceNameCache.ensureCapacity(&cachedNames, upTo: spaceNumber)
                let savedName = updatedNames[managedSpaceID]?.spaceName
                let resolvedName = resolveSpaceName(
                    from: savedName,
                    cache: cachedNames,
                    spaceNumber: spaceNumber,
                    isFullScreen: isFullScreen,
                    spaceDict: spaceDict)

                cachedNames[spaceNumber] = resolvedName

                let space = Space(
                    displayID: displayID,
                    spaceID: managedSpaceID,
                    spaceName: resolvedName,
                    spaceNumber: spaceNumber,
                    spaceByDesktopID: spaceByDesktopID,
                    isCurrentSpace: isCurrentSpace,
                    isFullScreen: isFullScreen)

                let nameInfo = SpaceNameInfo(
                    spaceNum: spaceNumber,
                    spaceName: resolvedName,
                    spaceByDesktopID: spaceByDesktopID)
                updatedNames[managedSpaceID] = nameInfo
                collectedSpaces.append(space)
            }
        }

        if cachedNames != originalCache {
            spaceNameCache.update(with: cachedNames)
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

    private func resolveSpaceName(
        from savedName: String?,
        cache: [String],
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
        if spaceNumber < cache.count {
            return cache[spaceNumber]
        }
        return "-"
    }
}

protocol SpaceObserverDelegate: AnyObject {
    func didUpdateSpaces(spaces: [Space])
}
