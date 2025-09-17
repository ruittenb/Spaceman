//
//  SpaceNameStore.swift
//  Spaceman
//
//  Created by ChatGPT on 16/09/25.
//

import Foundation

/// Centralizes reading and writing the per-space name information that is persisted in UserDefaults.
///
/// Historically the code touched `UserDefaults.standard` from multiple call sites, each performing their
/// own decode/encode cycle. Aside from duplicating work, that pattern made it easy to miss error handling
/// and complicated future changes to the storage format. `SpaceNameStore` wraps the persistence details in
/// one place and serializes access so callers can work with value-type dictionaries safely.
final class SpaceNameStore {
    static let shared = SpaceNameStore()

    private let defaults: UserDefaults
    private let key = "spaceNames"
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()
    private let queue = DispatchQueue(label: "dev.ruittenb.Spaceman.SpaceNameStore", attributes: .concurrent)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the complete dictionary of saved names. Callers get a value copy that they can mutate freely.
    func loadAll() -> [String: SpaceNameInfo] {
        queue.sync {
            guard let data = defaults.data(forKey: key) else { return [:] }
            return (try? decoder.decode([String: SpaceNameInfo].self, from: data)) ?? [:]
        }
    }

    /// Persists the given dictionary, replacing any existing stored data.
    func save(_ newValue: [String: SpaceNameInfo]) {
        queue.sync(flags: .barrier) {
            guard let data = try? encoder.encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    /// Loads the current dictionary, passes an inout copy to the mutating closure, and writes the result back.
    func update(_ mutate: (inout [String: SpaceNameInfo]) -> Void) {
        queue.sync(flags: .barrier) {
            var names = loadUnlocked()
            mutate(&names)
            guard let data = try? encoder.encode(names) else { return }
            defaults.set(data, forKey: key)
        }
    }

    /// Convenience for reading an entry for a single space.
    func nameInfo(for spaceID: String) -> SpaceNameInfo? {
        queue.sync {
            loadUnlocked()[spaceID]
        }
    }

    /// Convenience for saving or clearing a single entry.
    func setName(_ info: SpaceNameInfo?, for spaceID: String) {
        update { names in
            names[spaceID] = info
        }
    }

    // MARK: - Private helpers

    private func loadUnlocked() -> [String: SpaceNameInfo] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? decoder.decode([String: SpaceNameInfo].self, from: data)) ?? [:]
    }
}
