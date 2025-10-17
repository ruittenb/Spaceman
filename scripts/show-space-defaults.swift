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
    var colorHex: String?
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
let sortedSpaces = names.sorted { (a, b) in
    let displayA = a.value.currentDisplayIndex ?? 999
    let displayB = b.value.currentDisplayIndex ?? 999
    if displayA != displayB { return displayA < displayB }

    let posA = a.value.positionOnDisplay ?? 999
    let posB = b.value.positionOnDisplay ?? 999
    return posA < posB
}

// Calculate maximum space name length
let maxNameLength = sortedSpaces.map { $0.value.spaceName.count }.max() ?? 0

for (id, info) in sortedSpaces {
    let spaceNum = info.currentSpaceNumber.map(String.init) ?? "?"
    let display = info.displayUUID ?? "?"
    let pos = info.positionOnDisplay.map(String.init) ?? "?"
    let color = info.colorHex.map { "#\($0)" } ?? "none"

    // Right-align numbers, left-align name
    let paddedNum = String(repeating: " ", count: max(0, 2 - spaceNum.count)) + spaceNum
    let paddedName = info.spaceName.padding(toLength: maxNameLength, withPad: " ", startingAt: 0)
    let paddedID = String(repeating: " ", count: max(0, 2 - id.count)) + id
    let paddedPos = String(repeating: " ", count: max(0, 2 - pos.count)) + pos

    print("Space \(paddedNum): \(paddedName) (ID: \(paddedID), Display: \(display), Pos: \(paddedPos), Color: \(color))")
}
