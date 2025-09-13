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
    @Published var selectedSpace = 0
    // Preserve selection across reordering by using the managed space ID as a stable key
    @Published var selectedKey: String = ""
    @Published var spaceName = ""
    @Published var spaceByDesktopID = ""
    var spaceNamesDict: [String: SpaceNameInfo]!
    @Published var sortedSpaceNamesDict: [Dictionary<String, SpaceNameInfo>.Element]!
    var timer: Timer!
    
    init() {
        selectedSpace = -1
        spaceName = ""
        spaceNamesDict = [String: SpaceNameInfo]()
        sortedSpaceNamesDict = [Dictionary<String, SpaceNameInfo>.Element]()
        timer = Timer()
        if autoRefreshSpaces { startTimer() }
    }
    
    func loadData() {
        guard let data = UserDefaults.standard.value(forKey: "spaceNames") as? Data else {
            return
        }
        
        do {
            self.spaceNamesDict = try PropertyListDecoder().decode(Dictionary<String, SpaceNameInfo>.self, from: data)
        } catch {
            self.spaceNamesDict = [:]
        }
        
        let sorted = spaceNamesDict.sorted { (first, second) -> Bool in
            let a = first.value.currentOrder ?? first.value.spaceNum
            let b = second.value.currentOrder ?? second.value.spaceNum
            return a < b
        }
        sortedSpaceNamesDict = sorted
        if sortedSpaceNamesDict.isEmpty {
            sortedSpaceNamesDict.append((key: "0", value: SpaceNameInfo(spaceNum: 0, spaceName: "DISP", spaceByDesktopID: "1")))
        }
        // Restore selection by key if available; otherwise clamp index
        if !selectedKey.isEmpty, let idx = sortedSpaceNamesDict.firstIndex(where: { $0.key == selectedKey }) {
            selectedSpace = idx
        } else {
            if selectedSpace < 0 || selectedSpace >= sortedSpaceNamesDict.count { selectedSpace = 0 }
            selectedKey = sortedSpaceNamesDict[selectedSpace].key
        }
        // Sync fields to the current selected item
        spaceName = sortedSpaceNamesDict[selectedSpace].value.spaceName
        spaceByDesktopID = sortedSpaceNamesDict[selectedSpace].value.spaceByDesktopID
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
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(refreshSpaces), userInfo: nil, repeats: true)
    }
    
    func pauseTimer() {
        timer.invalidate()
    }
    
    @objc func refreshSpaces() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ButtonPressed"), object: nil)
    }
}
