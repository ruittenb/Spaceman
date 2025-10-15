//
//  DisplayGeometryUtilities.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 08/10/2025.
//

import Cocoa
import Foundation

class DisplayGeometryUtilities {
    static let verticalStackMargin: CGFloat = 20

    static func getDisplayCenter(display: NSDictionary) -> CGPoint {
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

    static func getDisplayHeight(display: NSDictionary) -> CGFloat {
        guard let uuidString = display["Display Identifier"] as? String else { return 0 }
        let uuid = CFUUIDCreateFromString(kCFAllocatorDefault, uuidString as CFString)
        let did = CGDisplayGetDisplayIDFromUUID(uuid)
        // Prefer NSScreen frame for consistent origin handling
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               CGDirectDisplayID(num.uint32Value) == did {
                return screen.frame.size.height
            }
        }
        return CGDisplayBounds(did).size.height
    }

    static func getIsVerticallyArranged(d1: NSDictionary, d2: NSDictionary) -> Bool {
        // Displays are vertically stacked if deltaY is within margin from average height
        let c1 = DisplayGeometryUtilities.getDisplayCenter(display: d1)
        let c2 = DisplayGeometryUtilities.getDisplayCenter(display: d2)
        let height1 = getDisplayHeight(display: d1)
        let height2 = getDisplayHeight(display: d2)
        let averageHeight = (height1 + height2) / 2
        let deltaY = abs(c1.y - c2.y)
        return abs(deltaY - averageHeight) < verticalStackMargin
    }

    static func getIsHorizontallyArranged(d1: NSDictionary, d2: NSDictionary) -> Bool {
        return !getIsVerticallyArranged(d1: d1, d2: d2)
    }
}
