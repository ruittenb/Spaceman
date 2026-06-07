//
//  PreferencesViewModel.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 6/12/20.
//

import Foundation
import SwiftUI

class PreferencesViewModel: ObservableObject {
    let nameStore: SpaceNameStore
    @Published var spaceNamesDict: [String: SpaceNameInfo] = [:]
    @Published var sortedSpaceNamesDict: [Dictionary<String, SpaceNameInfo>.Element] = []
    @Published var backupStatusMessage: String?
    @Published var backupStatusIsError: Bool = false
    @Published var restoreStatusMessage: String?
    @Published var restoreStatusIsError: Bool = false
    @Published var lastBackupDate: Date?

    private static let settingsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".spaceman")
    private static let settingsFile = settingsDirectory.appendingPathComponent("app-defaults.xml")
    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "dev.ruittenb.Spaceman"

    init(nameStore: SpaceNameStore = .shared) {
        self.nameStore = nameStore
        refreshBackupDate()
    }

    func loadData() {
        let allSpaceNames = nameStore.loadAll()
        let filtered = allSpaceNames.filter { AppDelegate.activeSpaceIDs.contains($0.key) }
        spaceNamesDict = filtered
        rebuildSortedSpaceNames()
    }

    func updateSpace(for key: String, to newName: String) {
        updateSpaceName(for: key, to: newName)
    }

    private func updateSpaceName(for key: String, to newName: String) {
        guard let info = spaceNamesDict[key] else { return }
        spaceNamesDict[key] = info.withName(newName)
    }

    func updateSpaceColor(for key: String, to color: NSColor?) {
        guard let info = spaceNamesDict[key] else { return }
        spaceNamesDict[key] = info.withColor(color?.toHexString())

        // Save immediately but don't rebuild sorted array (avoids ForEach recreation).
        // Use update() to merge into existing store, preserving disconnected display entries.
        nameStore.update { stored in
            for (key, info) in spaceNamesDict {
                stored[key] = info
            }
        }
    }

    func removeAllColors() {
        for key in spaceNamesDict.keys {
            spaceNamesDict[key]?.colorHex = nil
        }
        nameStore.update { stored in
            for key in stored.keys {
                stored[key]?.colorHex = nil
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
            sortedSpaceNamesDict.append((
                key: "0",
                value: SpaceNameInfo(spaceNum: 0, spaceName: "DISP", spaceLabel: "1")))
        }
    }

    // MARK: - Backup / Restore

    func backupPreferences() {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Self.settingsDirectory, withIntermediateDirectories: true)
            guard let domain = UserDefaults.standard.persistentDomain(forName: Self.bundleIdentifier) else {
                showBackupStatus(String(localized: "No preferences to backup"), isError: true)
                return
            }
            let data = try PropertyListSerialization.data(fromPropertyList: domain, format: .xml, options: 0)
            try data.write(to: Self.settingsFile)

            // Timestamped backup, matching Makefile convention
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withYear, .withMonth, .withDay, .withDashSeparatorInDate,
                .withTime, .withColonSeparatorInTime, .withTimeZone]
            let timestamp = formatter.string(from: Date())
            let timestampedFile = Self.settingsDirectory.appendingPathComponent("app-defaults-\(timestamp).xml")
            try data.write(to: timestampedFile)

            refreshBackupDate()
            showBackupStatus(String(localized: "Preferences saved"), isError: false)
        } catch {
            showBackupStatus(String(localized: "Backup failed"), isError: true)
        }
    }

    static func restoreFromBackup() throws {
        let data = try Data(contentsOf: settingsFile)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data, format: nil) as? [String: Any] else {
            throw NSError(domain: "Spaceman", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid backup file"])
        }
        LegacyMigrations.resetMigratedKeys()
        UserDefaults.standard.setPersistentDomain(dict, forName: bundleIdentifier)
        LegacyMigrations.perform()
        postSettingsChanged()
    }

    func restorePreferences() {
        do {
            try Self.restoreFromBackup()
            loadData()
            showRestoreStatus(String(localized: "Preferences restored"), isError: false)
        } catch {
            showRestoreStatus(String(localized: "Restore failed"), isError: true)
        }
    }

    func refreshBackupDate() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: Self.settingsFile.path)
        lastBackupDate = attrs?[.modificationDate] as? Date
    }

    private func showBackupStatus(_ message: String, isError: Bool) {
        backupStatusMessage = message
        backupStatusIsError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.backupStatusMessage = nil
        }
    }

    private func showRestoreStatus(_ message: String, isError: Bool) {
        restoreStatusMessage = message
        restoreStatusIsError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.restoreStatusMessage = nil
        }
    }
}
