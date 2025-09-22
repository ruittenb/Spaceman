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
    @Published var selectedSpace = 0
    @Published var spaceName = ""
    @Published var spaceByDesktopID = ""
    @Published var spaceNamesDict: [String: SpaceNameInfo] = [:]
    @Published var sortedSpaceNamesDict: [Dictionary<String, SpaceNameInfo>.Element] = []
    var timer: Timer!
    
    init() {
        selectedSpace = -1
        spaceName = ""
        timer = Timer()
        if autoRefreshSpaces { startTimer() }
    }
    
    func loadData() {
        spaceNamesDict = nameStore.loadAll()
        rebuildSortedSpaceNames(maintainingSelectionFor: nil)
    }
    
    func updateSpace() {
        let key = sortedSpaceNamesDict[selectedSpace].key
        let spaceNum = sortedSpaceNamesDict[selectedSpace].value.spaceNum
        let spaceByDesktopID = sortedSpaceNamesDict[selectedSpace].value.spaceByDesktopID
        spaceNamesDict[key] = SpaceNameInfo(
            spaceNum: spaceNum,
            spaceName: spaceName.isEmpty ? "-" : spaceName,
            spaceByDesktopID: spaceByDesktopID)
    }

    func updateSpace(at index: Int, to newName: String) {
        guard index >= 0 && index < sortedSpaceNamesDict.count else { return }
        let key = sortedSpaceNamesDict[index].key
        let info = sortedSpaceNamesDict[index].value
        spaceNamesDict[key] = SpaceNameInfo(
            spaceNum: info.spaceNum,
            spaceName: newName.isEmpty ? "-" : newName,
            spaceByDesktopID: info.spaceByDesktopID)
    }

    func updateSpace(for key: String, to newName: String) {
        guard let info = spaceNamesDict[key] else { return }
        spaceNamesDict[key] = SpaceNameInfo(
            spaceNum: info.spaceNum,
            spaceName: newName.isEmpty ? "-" : newName,
            spaceByDesktopID: info.spaceByDesktopID)
    }

    func persistChanges(for key: String?) {
        nameStore.save(spaceNamesDict)
        rebuildSortedSpaceNames(maintainingSelectionFor: key)
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

    private func rebuildSortedSpaceNames(maintainingSelectionFor key: String?) {
        let previousKey = key ?? (selectedSpace >= 0 && selectedSpace < sortedSpaceNamesDict.count ? sortedSpaceNamesDict[selectedSpace].key : nil)

        sortedSpaceNamesDict = spaceNamesDict.sorted { $0.value.spaceNum < $1.value.spaceNum }

        if sortedSpaceNamesDict.isEmpty {
            sortedSpaceNamesDict.append((key: "0", value: SpaceNameInfo(spaceNum: 0, spaceName: "DISP", spaceByDesktopID: "1")))
        }

        if let previousKey, let restoredIndex = sortedSpaceNamesDict.firstIndex(where: { $0.key == previousKey }) {
            selectedSpace = restoredIndex
        } else {
            selectedSpace = 0
        }

        spaceName = sortedSpaceNamesDict[selectedSpace].value.spaceName
        spaceByDesktopID = sortedSpaceNamesDict[selectedSpace].value.spaceByDesktopID
    }
}
