//
//  SpaceLabelController.swift
//  Spaceman
//
//  Manages floating label windows for Mission Control space previews.
//

import Cocoa

class SpaceLabelController {
    private var windows: [String: SpaceLabelWindow] = [:]
    private var enabled: Bool { UserDefaults.standard.bool(forKey: "showMissionControlLabels") }
    private var showWorkItem: DispatchWorkItem?
    private var lastVisibleIDs: Set<String> = []

    private let showDelay: TimeInterval = 0.4

    func update(spaces: [Space]) {
        guard enabled else {
            removeAll()
            return
        }

        let currentIDs = Set(spaces.map(\.spaceID))
        let visibleIDs = Set(spaces.filter(\.isCurrentSpace).map(\.spaceID))
        let spaceChanged = visibleIDs != lastVisibleIDs
        lastVisibleIDs = visibleIDs

        // Cancel pending show operation
        showWorkItem?.cancel()
        showWorkItem = nil

        // Remove windows for deleted spaces
        for spaceID in windows.keys where !currentIDs.contains(spaceID) {
            windows[spaceID]?.close()
            windows.removeValue(forKey: spaceID)
        }

        // Create windows for new spaces (but don't show yet)
        for space in spaces where windows[space.spaceID] == nil {
            let window = SpaceLabelWindow(spaceID: space.spaceID, name: space.spaceName)
            windows[space.spaceID] = window
        }

        // Update names
        for space in spaces {
            windows[space.spaceID]?.updateName(space.spaceName)
        }

        // If space changed, hide ALL labels immediately
        if spaceChanged {
            hideAll()

            // Show non-current labels after delay
            let workItem = DispatchWorkItem { [weak self] in
                self?.showNonCurrentLabels(visibleIDs: visibleIDs)
            }
            showWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: workItem)
        } else {
            // No space change - just ensure visibility is correct
            showNonCurrentLabels(visibleIDs: visibleIDs)
        }
    }

    private func hideAll() {
        for window in windows.values {
            window.orderOut(nil)
        }
    }

    private func showNonCurrentLabels(visibleIDs: Set<String>) {
        for (spaceID, window) in windows {
            if visibleIDs.contains(spaceID) {
                window.orderOut(nil)
            } else {
                if !window.isVisible {
                    window.orderFront(nil)
                    window.bindToSpace()
                }
            }
        }
    }

    func removeAll() {
        showWorkItem?.cancel()
        showWorkItem = nil
        windows.values.forEach { $0.close() }
        windows.removeAll()
    }

    func rebindAll() {
        windows.values.forEach { $0.bindToSpace() }
    }
}
