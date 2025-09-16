//
//  SpaceNameCache.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 02/09/2024.
//

import Foundation
import SwiftUI

class SpaceNameCache {
    @AppStorage("spaceNameCache")  private var spaceNameCacheString: String = ""
    private let emptyChunk = Array(repeating: "-", count: 5)
    
    var cache: [String] {
        get {
            if let data = spaceNameCacheString.data(using: .utf8) {
                let decoded = try? JSONDecoder().decode([String].self, from: data)
                if (decoded != nil) {
                    return decoded!
                }
            }
            return emptyChunk
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                spaceNameCacheString = String(data: encoded, encoding: .utf8) ?? ""
            }
        }
    }
    
    func ensureCapacity(_ storage: inout [String], upTo index: Int) {
        while index >= storage.count {
            storage.append(contentsOf: emptyChunk)
        }
    }
}
