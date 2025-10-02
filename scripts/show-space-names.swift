#!/usr/bin/swift

import Foundation

let defaults = UserDefaults.standard
defaults.addSuite(named: "dev.ruittenb.Spaceman")

struct SpaceNameInfo: Codable {
    let spaceNum: Int
    let spaceName: String
    let spaceByDesktopID: String
    var displayUUID: String?
    var positionOnDisplay: Int?
    var currentDisplayIndex: Int?
    var currentSpaceNumber: Int?
}

guard let data = defaults.data(forKey: "spaceNames") else {
    print("No space names stored")
    exit(0)
}

let decoder = PropertyListDecoder()
guard let names = try? decoder.decode([String: SpaceNameInfo].self, from: data) else {
    print("Failed to decode space names")
    exit(1)
}

// Sort by display and position
let sorted = names.sorted { (a, b) in
    let displayA = a.value.currentDisplayIndex ?? 999
    let displayB = b.value.currentDisplayIndex ?? 999
    if displayA != displayB { return displayA < displayB }

    let posA = a.value.positionOnDisplay ?? 999
    let posB = b.value.positionOnDisplay ?? 999
    return posA < posB
}

for (id, info) in sorted {
    let spaceNum = info.currentSpaceNumber.map(String.init) ?? "?"
    let display = info.displayUUID ?? "?"
    let pos = info.positionOnDisplay.map(String.init) ?? "?"
    print("Space \(spaceNum): \(info.spaceName) (ID: \(id), Display: \(display), Pos: \(pos))")
}
