//
//  SpaceFilter.swift
//  Spaceman
//
//  Created by Claude Code 13/10/2025
//  Extracted from IconCreator for better testability
//

import Foundation

/// Filters spaces based on visibility mode and neighbor radius
struct SpaceFilter {

    /// Filters spaces according to the specified visibility mode
    /// - Parameters:
    ///   - spaces: All available spaces
    ///   - mode: The visibility mode (all, neighbors, currentOnly)
    ///   - neighborRadius: Number of spaces to show on each side of current space (for neighbors mode)
    ///   - hideInactiveSpaces: Legacy flag for backward compatibility
    /// - Returns: Filtered array of spaces to display
    func filter(
        _ spaces: [Space],
        mode: VisibleSpacesMode,
        neighborRadius: Int,
        hideInactiveSpaces: Bool = false
    ) -> [Space] {
        // Backwards compatibility: if legacy flag is true and visible mode wasn't set explicitly,
        // treat as current only
        let effectiveMode: VisibleSpacesMode = {
            // Note: This logic is handled by IconCreator checking UserDefaults
            // We pass the effective mode here
            return mode
        }()

        switch effectiveMode {
        case .all:
            return spaces

        case .currentOnly:
            return spaces.filter { $0.isCurrentSpace }

        case .neighbors:
            var filtered: [Space] = []
            var group: [Space] = []
            var currentDisplayID = spaces.first?.displayID ?? ""

            func flushGroup() {
                guard group.count > 0 else { return }
                if let activeIndex = group.firstIndex(where: { $0.isCurrentSpace }) {
                    let radius = max(0, neighborRadius)
                    let start = max(0, activeIndex - radius)
                    let end = min(group.count - 1, activeIndex + radius)
                    filtered.append(contentsOf: group[start...end])
                }
                group.removeAll(keepingCapacity: true)
            }

            for s in spaces {
                if s.displayID != currentDisplayID {
                    flushGroup()
                    currentDisplayID = s.displayID
                }
                group.append(s)
            }
            flushGroup()

            if filtered.isEmpty {
                // Fallback to current-only to avoid empty UI during transitions
                return spaces.filter { $0.isCurrentSpace }
            }
            return filtered
        }
    }
}
