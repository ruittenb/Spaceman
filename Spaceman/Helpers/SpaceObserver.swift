//
//  SpaceObserver.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Cocoa
import Foundation
import SwiftUI

class SpaceObserver {
    @AppStorage("restartNumberingByDesktop") private var restartNumberingByDesktop = false
    @AppStorage("displayOrderPriority") private var displayOrderPriority = DisplayOrderPriority.horizontal
    @AppStorage("horizontalDirection") private var horizontalDirection = HorizontalDirection.leftToRight
    @AppStorage("verticalDirection") private var verticalDirection = VerticalDirection.topToBottom
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.medium
    
    private let workspace = NSWorkspace.shared
    private let conn = _CGSDefaultConnection()
    private let defaults = UserDefaults.standard
    private let spaceNameCache = SpaceNameCache()

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

    // Compare two displays according to user preferences
    func compareDisplays(d1: NSDictionary, d2: NSDictionary) -> Bool {
        let c1 = getDisplayCenter(display: d1)
        let c2 = getDisplayCenter(display: d2)
        let tol: CGFloat = 2
        let cmpX: (CGPoint, CGPoint) -> Bool = { a, b in
            switch self.horizontalDirection {
            case .leftToRight: return a.x < b.x
            case .rightToLeft: return a.x > b.x
            }
        }
        let cmpY: (CGPoint, CGPoint) -> Bool = { a, b in
            // macOS global coordinates origin at bottom-left; larger y is higher
            switch self.verticalDirection {
            case .topToBottom: return a.y > b.y
            case .bottomToTop: return a.y < b.y
            }
        }
        switch displayOrderPriority {
        case .horizontal:
            if abs(c1.x - c2.x) > tol { return cmpX(c1, c2) }
            return cmpY(c1, c2)
        case .vertical:
            if abs(c1.y - c2.y) > tol { return cmpY(c1, c2) }
            return cmpX(c1, c2)
        }
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
        var displays = CGSCopyManagedDisplaySpaces(conn)!.takeRetainedValue() as! [NSDictionary]

        // create dict with correct sorting before changing it
        var spaceNumberDict: [String: Int] = [:]
        var spacesIndex = 1
        for d in displays {
            guard let spaces = d["Spaces"] as? [[String: Any]]
            else {
                continue
            }
            
            for s in spaces {
                let managedSpaceID = String(s["ManagedSpaceID"] as! Int)
                spaceNumberDict[managedSpaceID] = spacesIndex
                spacesIndex += 1
            }
        }
        
        // Sort displays based on user preference
        displays.sort { a, b in compareDisplays(d1: a, d2: b) }

        // Map sorted display to index (1..D)
        var currentDisplayIndexByID: [String: Int] = [:]
        for (idx, d) in displays.enumerated() {
            if let displayID = d["Display Identifier"] as? String { currentDisplayIndexByID[displayID] = idx + 1 }
        }
        
        var activeSpaceID = -1
        var allSpaces = [Space]()
        var updatedDict = [String: SpaceNameInfo]()
        var lastSpaceByDesktopNumber = 0
        var currentOrder = 0
        
        for d in displays {
            guard let currentSpaces = d["Current Space"] as? [String: Any],
                  let spaces = d["Spaces"] as? [[String: Any]],
                  let displayID = d["Display Identifier"] as? String
            else {
                continue
            }
            
            activeSpaceID = currentSpaces["ManagedSpaceID"] as! Int
            
            if activeSpaceID == -1 {
                DispatchQueue.main.async {
                    print("Can't find current space")
                }
                return
            }

            var lastFullScreenSpaceNumber = 0
            if (restartNumberingByDesktop) {
                lastSpaceByDesktopNumber = 0
            }

            for s in spaces {
                let managedSpaceID = String(s["ManagedSpaceID"] as! Int)
                let spaceNumber = spaceNumberDict[managedSpaceID]!
                let isCurrentSpace = activeSpaceID == s["ManagedSpaceID"] as! Int
                let isFullScreen = s["TileLayoutManager"] as? [String: Any] != nil
                let spaceByDesktopID: String
                if !isFullScreen {
                    lastSpaceByDesktopNumber += 1
                    spaceByDesktopID = String(lastSpaceByDesktopNumber)
                } else {
                    lastFullScreenSpaceNumber += 1
                    spaceByDesktopID = "F\(lastFullScreenSpaceNumber)"
                }
                // 2aa1db4 logic: seed name from SpaceNameCache, then override with saved mapping/fullscreen
                while spaceNumber >= spaceNameCache.cache.count { spaceNameCache.extend() }
                var seededName = spaceNameCache.cache[spaceNumber]
                
                if let data = defaults.data(forKey: "spaceNames"),
                   let dict = try? PropertyListDecoder().decode([String: SpaceNameInfo].self, from: data),
                   let saved = dict[managedSpaceID]
                {
                    seededName = saved.spaceName
                    
                } else if isFullScreen {
                    if let pid = s["pid"] as? pid_t,
                       let app = NSRunningApplication(processIdentifier: pid),
                       let name = app.localizedName
                    {
                        seededName = name.prefix(4).uppercased()
                        
                    } else {
                        seededName = "FULL"
                        
                    }
                } else {
                    // Fall back to cache seed (could be '-') when no saved mapping and not fullscreen
                    
                }
                var space = Space(displayID: displayID,
                                  spaceID: managedSpaceID,
                                  spaceName: seededName,
                                  spaceNumber: spaceNumber,
                                  spaceByDesktopID: spaceByDesktopID,
                                  isCurrentSpace: isCurrentSpace,
                                  isFullScreen: isFullScreen)
                // Write back to cache
                spaceNameCache.cache[spaceNumber] = space.spaceName
                
                currentOrder += 1
                var nameInfo = SpaceNameInfo(spaceNum: spaceNumber, spaceName: space.spaceName, spaceByDesktopID: spaceByDesktopID)
                nameInfo.currentDisplayIndex = currentDisplayIndexByID[displayID]
                nameInfo.currentOrder = currentOrder
                updatedDict[managedSpaceID] = nameInfo
                allSpaces.append(space)
            }
        }
        
        defaults.set(try? PropertyListEncoder().encode(updatedDict), forKey: "spaceNames")
        delegate?.didUpdateSpaces(spaces: allSpaces)
    }
}

protocol SpaceObserverDelegate: AnyObject {
    func didUpdateSpaces(spaces: [Space])
}
