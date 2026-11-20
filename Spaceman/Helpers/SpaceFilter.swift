//
//  SpaceFilter.swift
//  Spaceman
//
//  Created by René Uittenbogaard on 2025-10-13.
//  Co-author: Claude Code
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
    /// - Returns: Filtered array of spaces to display
    func filter(
        _ spaces: [Space],
        mode: VisibleSpacesMode,
        neighborRadius: Int
    ) -> [Space] {
        switch mode {
        case .all:
            return spaces

        case .currentOnly:
            return spaces.filter { $0.isCurrentSpace }

        case .neighbors:
            var filtered: [Space] = []
            var group: [Space] = []
            var currentDisplayID = spaces.first?.displayID ?? ""

            func flushGroup() {
                guard !group.isEmpty else { return }
                if let activeIndex = group.firstIndex(where: { $0.isCurrentSpace }) {
                    let radius = max(0, neighborRadius)
                    let start = max(0, activeIndex - radius)
                    let end = min(group.count - 1, activeIndex + radius)
                    filtered.append(contentsOf: group[start...end])
                }
                group.removeAll(keepingCapacity: true)
            }

            for space in spaces {
                if space.displayID != currentDisplayID {
                    flushGroup()
                    currentDisplayID = space.displayID
                }
                group.append(space)
            }
            flushGroup()

            // During transitions (e.g. wake, display connect/disconnect), macOS may
            // report no current space at all, which leaves `filtered` empty. No fallback
            // is needed: falling back to the current spaces would be empty as well.
            return filtered
        }
    }
}
