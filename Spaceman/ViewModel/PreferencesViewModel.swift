//
//  PreferencesViewModel.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 6/12/20.
//

import Foundation
import SwiftUI

class PreferencesViewModel: ObservableObject {
    @AppStorage("autoRefreshSpaces") private var autoRefreshSpaces = false
    private let nameStore = SpaceNameStore.shared
    @Published var spaceNamesDict: [String: SpaceNameInfo] = [:]
    @Published var sortedSpaceNamesDict: [Dictionary<String, SpaceNameInfo>.Element] = []
    var timer: Timer!

    init() {
        timer = Timer()
        if autoRefreshSpaces { startTimer() }
    }

    func loadData() {
        let allSpaceNames = nameStore.loadAll()
        let filtered = allSpaceNames.filter { AppDelegate.activeSpaceIDs.contains($0.key) }

        // Preserve any local changes (like colors) that might not be in the loaded data yet
        var merged = filtered
        for (key, existingInfo) in spaceNamesDict {
            if let loadedInfo = filtered[key] {
                // Prefer loaded data but keep local color if it's newer
                if existingInfo.colorHex != nil && loadedInfo.colorHex == nil {
                    var updated = loadedInfo
                    updated.colorHex = existingInfo.colorHex
                    merged[key] = updated
                }
            }
        }

        spaceNamesDict = merged
        rebuildSortedSpaceNames()
    }

    func updateSpace(for key: String, to newName: String) {
        updateSpaceName(for: key, to: newName)
    }

    private func updateSpaceName(for key: String, to newName: String) {
        guard let info = spaceNamesDict[key] else { return }
        // Update only the name, preserve all other fields
        var updatedInfo = SpaceNameInfo(
            spaceNum: info.spaceNum,
            spaceName: newName,
            spaceByDesktopID: info.spaceByDesktopID)
        updatedInfo.displayUUID = info.displayUUID
        updatedInfo.positionOnDisplay = info.positionOnDisplay
        updatedInfo.currentDisplayIndex = info.currentDisplayIndex
        updatedInfo.currentSpaceNumber = info.currentSpaceNumber
        updatedInfo.colorHex = info.colorHex
        spaceNamesDict[key] = updatedInfo
    }

    func updateSpaceColor(for key: String, to color: NSColor?) {
        guard let info = spaceNamesDict[key] else { return }
        let hexString = color?.toHexString()

        var updatedInfo = SpaceNameInfo(
            spaceNum: info.spaceNum,
            spaceName: info.spaceName,
            spaceByDesktopID: info.spaceByDesktopID)
        updatedInfo.displayUUID = info.displayUUID
        updatedInfo.positionOnDisplay = info.positionOnDisplay
        updatedInfo.currentDisplayIndex = info.currentDisplayIndex
        updatedInfo.currentSpaceNumber = info.currentSpaceNumber
        updatedInfo.colorHex = hexString
        spaceNamesDict[key] = updatedInfo

        // Save immediately but don't rebuild sorted array (avoids ForEach recreation).
        // Use update() to merge into existing store, preserving disconnected display entries.
        nameStore.update { stored in
            for (key, info) in spaceNamesDict {
                stored[key] = info
            }
        }
    }

    func persistChanges(for key: String?) {
        // Merge into existing store, preserving disconnected display entries.
        nameStore.update { stored in
            for (key, info) in spaceNamesDict {
                stored[key] = info
            }
        }
        rebuildSortedSpaceNames()
    }

    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(refreshSpaces), userInfo: nil, repeats: true)
    }

    func pauseTimer() {
        timer.invalidate()
    }

    @objc func refreshSpaces() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
    }

    private func rebuildSortedSpaceNames() {
        // Sort by display index, then by position on display (respects display ordering)
        sortedSpaceNamesDict = spaceNamesDict.sorted { (first, second) in
            let displayA = first.value.currentDisplayIndex ?? 0
            let displayB = second.value.currentDisplayIndex ?? 0

            if displayA != displayB {
                return displayA < displayB
            }

            let positionA = first.value.positionOnDisplay ?? 0
            let positionB = second.value.positionOnDisplay ?? 0
            return positionA < positionB
        }

        if sortedSpaceNamesDict.isEmpty {
            sortedSpaceNamesDict.append((key: "0", value: SpaceNameInfo(spaceNum: 0, spaceName: "DISP", spaceByDesktopID: "1")))
        }
    }
}
