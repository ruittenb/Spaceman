//
//  SpaceNameCache.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 02/09/2024.
//

import Foundation

final class SpaceNameCache {
    private let emptyChunk = Array(repeating: "-", count: 5)
    private var storage: [String] = []
    private let lock = NSLock()

    func snapshot() -> [String] {
        lock.withLock { storage.isEmpty ? emptyChunk : storage }
    }

    func update(with newValue: [String]) {
        lock.withLock { storage = newValue }
    }

    func ensureCapacity(_ storage: inout [String], upTo index: Int) {
        while index >= storage.count {
            storage.append(contentsOf: emptyChunk)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
