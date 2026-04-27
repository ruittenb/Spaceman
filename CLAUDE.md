# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Spaceman is a macOS menu bar application that displays Spaces/Virtual Desktops. Built with Swift and SwiftUI using Xcode (not SPM).

## Build Commands

**NEVER build.** Do not run `make`, `xcodebuild`, or any other build commands. The user will build manually. Tell them to.

## Build Artifacts

The `build/` directory contains `*.dmg` release artifacts for every version. These MUST NOT be deleted — they are the distribution archives.

## macOS Integration

The app uses **private** Core Graphics APIs (`CGSCopyManagedDisplaySpaces`, `_CGSDefaultConnection`). These have no public documentation. SourceKit diagnostics for these APIs and cross-module types are false positives — they compile fine via xcodebuild. Don't try to "fix" them.

## Code Signing

This project does not have a developer certificate, so no code signing or notarization takes place.

## Testing

```bash
xcodebuild test -project Spaceman.xcodeproj -scheme Spaceman -destination platform=macOS
```

## Linting

Never write `.swift` lines longer than 120 characters: SwiftLint will flag them.

## Space Name Persistence — The ManagedSpaceID Problem

This section documents a subtle and recurring class of bugs around persisting user-assigned space names. Issues #17, #20, #22, #22b, #22c, #22d, and #29 all stem from the same root cause. If you're touching `SpaceObserver`, `SpaceNameStore`, `PreferencesViewModel`, or `SpaceNameInfo`, read this first.

### What macOS does with ManagedSpaceIDs

macOS identifies spaces internally via `ManagedSpaceID` (an integer from `CGSCopyManagedDisplaySpaces`). The app stores user-assigned names keyed by this ID. There is no macOS API that tells you when or why IDs change. The app must infer it from context.

Observed macOS behavior:

| Scenario | IDs | Positions | Spaces move? |
|----------|-----|-----------|--------------|
| **Reboot / wake from sleep** | Reassigned (may swap) | Stable per display | No |
| **User reorder in Mission Control** | Stable | Changed | No |
| **Lid close** | Mostly stable | Changed (spaces migrate to remaining display) | Yes |
| **Lid open** | Partially reassigned (at least on the external display) | Changed (spaces migrate back) | Yes |
| **Mirror ↔ extend** | May be reassigned | Changed | Yes |
| **Sleep → mirror → wake** | May be reassigned | Transient (unstable during reconfiguration) | Yes |

The critical distinction is between row 1 and rows 3–5. Reboot looks like a topology change but requires the *opposite* strategy. Getting this wrong corrupts the name store. Row 6 (sleep→mirror→wake) is a compound event: both wake and topology change fire simultaneously. Topology must take priority because positions are transient while macOS reconfigures the display (issue #29).

Note on the "lid close/open" rows: during the close→open round trip, IDs on one display may survive while IDs on another display get reassigned. The fix must handle both stable and reassigned IDs within the same topology change event.

### The two-part fix for topology changes

Topology changes (lid close/open, mirror↔extend) are hard because both IDs and positions may change — but not necessarily in the same direction or on the same display. The fix has two parts that work together:

**Part 1 — ID-first matching (`SpaceNameMatchingStrategy.idWithPositionFallback`):** Try matching by ManagedSpaceID first. If the ID is in the store, we know exactly which name belongs to this space. If not (ID was reassigned), fall back to position matching with disconnected display fallback. This avoids the misassignment that pure position matching causes when spaces migrate between displays.

**Part 2 — Position preservation:** When Part 1 finds an entry by ID during a topology change, preserve the stored `displayUUID` and `positionOnDisplay` instead of overwriting them with the current (transient) values. This is critical because the space may temporarily sit at a different position on a different display. If we saved that transient position, and macOS later assigns a new ID (e.g., on lid reopen), position matching would look for the stored position and fail.

Both parts are necessary. Part 1 alone was not enough (issue #22c): ID matching correctly resolved "2ND" during lid close, but the stored position was updated from `pos 1` to `pos 10` (the transient position on the combined single-display). When the lid reopened and macOS assigned a new ID, position matching looked for `externalUUID/pos 1` but found `pos 10`. Name lost.

### The three matching strategies

The app uses `SpaceNameMatchingStrategy` (an enum) to choose per display, per update:

**`.positionOnly`** — Match stored names to spaces by display UUID + position number. Used after **wake/reboot** (`_needsPositionRevalidation` flag). This is the only strategy that handles ID swaps correctly: if space 1 and space 2 swap IDs after reboot, position matching ignores the swapped IDs and assigns names by where the spaces sit.

**`.idWithPositionFallback`** — Try matching by ManagedSpaceID first, with position fallback for unknown IDs. Used when the **display topology changes** (`topologyChanged`) or when a **display UUID has no stored entries**. When the ID is found, the stored display/position metadata is preserved (not updated to the transient values). When the ID is not found, position matching with disconnected display fallback is used, and the current position is stored normally.

**`.idOnly`** — Match by ManagedSpaceID only. Used during **normal operation**. IDs are stable and follow spaces when the user reorders them in Mission Control. Positions are updated to current values.

### Concrete failure: the lid close/open round trip

This scenario drove issues #22b and #22c. Understanding it is the key to understanding why the code is the way it is.

**Setup:** Laptop has 9 named spaces (positions 1–9). External display has 1 space named "2ND" (position 1).

**Close lid** — all spaces collapse onto external display (~10 spaces):

| Approach | What happens | Result |
|----------|-------------|--------|
| `.positionOnly` (issue #22b) | Position 1 on external finds stored `externalUUID/pos 1` → "2ND". Wrong — that space is the laptop's "CAL". Real "2ND" at pos 10 gets no match. | "2ND" overwritten, permanently lost |
| `.idWithPositionFallback` without position preservation (issue #22c) | ID matching finds "2ND" correctly. But store is updated to `externalUUID/pos 10`. | Name correct during lid-closed state... |
| `.idWithPositionFallback` with position preservation (current fix) | ID matching finds "2ND" correctly. Store keeps `externalUUID/pos 1`. | Name correct, position preserved for recovery |

**Open lid** — spaces return to two displays, external space may get a new ManagedSpaceID:

| Approach | What happens | Result |
|----------|-------------|--------|
| After #22b | Store is already corrupted — "2ND" gone | Lost |
| After #22c (no preservation) | New ID → ID matching fails. Position matching looks for `externalUUID/pos 1` → store says `pos 10` → no match | Lost |
| After current fix (with preservation) | New ID → ID matching fails. Position matching looks for `externalUUID/pos 1` → store says `pos 1` → match! | **Recovered** ✓ |

### Why wake/reboot must NOT use ID-first matching

After reboot, macOS may swap IDs: space at position 1 gets the ID that position 2 used to have, and vice versa. Both IDs exist in the store, so ID matching would confidently return the *wrong* name for each. Position matching ignores IDs entirely and assigns by where spaces sit, which is stable across reboots.

### Why wake + topology change must use ID-first matching (issue #29)

When wake and topology change happen simultaneously (e.g., close lid → connect external in mirroring → open lid), both `_needsPositionRevalidation` and `topologyChanged` are true. Previously, wake always took priority and forced `.positionOnly`. But `.positionOnly` assumes the display topology is unchanged — it matches names to positions on the same display. When the topology *also* changed, macOS may report a different display UUID and the space order may not have stabilized yet. Position matching against this transient state misassigns names (spaces 1 and 2 were corrupted in the observed case). Once the first update writes the bad matches, subsequent updates preserve the corruption.

**Fix:** When both flags are true, topology wins → `.idWithPositionFallback`. IDs are more reliable than positions when the display configuration is changing. This is consistent with the general principle: topology changes use ID-first matching, wake-only uses position matching.

### How the strategy is selected

In `performSpaceInformationUpdate()`, for each display:

```
if _needsPositionRevalidation AND NOT inTopologyTransition (wake/reboot, same displays):
    → .positionOnly
else if inTopologyTransition OR _needsPositionRevalidation OR displayUUID not in stored entries:
    → .idWithPositionFallback
else:
    → .idOnly
```

**`_needsPositionRevalidation`** starts `true` (app launch) and is set `true` on `NSWorkspace.didWakeNotification`. Captured and cleared at the start of each `updateSpaceInformation()`.

**`topologyChanged`** is computed in the worker queue by comparing the current set of display UUIDs against `_lastKnownDisplayIDs`. This detects lid close/open, mirror↔extend, and display connect/disconnect.

**`inTopologyTransition`** is `topologyChanged || _topologyChangeGracePeriod > 0`. The grace period counter is set to 5 when a topology change is detected and decremented each update. This ensures follow-up updates (from rapid macOS notifications) also use `.idWithPositionFallback` instead of `.idOnly`, preventing position corruption (issue #22d).

**`NSApplication.didChangeScreenParametersNotification`** triggers `updateSpaceInformation()` so the app notices topology changes even when no space-change notification fires.

### Position preservation details

After `resolveSpaceNameInfo` returns a match, the code builds a new `SpaceNameInfo` for `updatedNames`. The position/display fields are set as follows:

```
if strategy == .idWithPositionFallback AND storedNames[managedSpaceID] exists:
    // Entry was found by ID → preserve stored display/position
    nameInfo.displayUUID = savedInfo.displayUUID
    nameInfo.positionOnDisplay = savedInfo.positionOnDisplay
else:
    // Entry was found by position, or strategy is positionOnly/idOnly
    nameInfo.displayUUID = current displayID
    nameInfo.positionOnDisplay = current position
```

The `currentDisplayIndex` and `currentSpaceNumber` fields (used for UI display) are always set to current values regardless of strategy.

### Disconnected display fallback

When an external display is reconnected, macOS sometimes assigns it a new display UUID. The display has no stored entries under the new UUID, so `idWithPositionFallback` is used. The ID lookup fails (new IDs), so it falls back to position matching.

`findSpaceByPosition()` accepts an optional `connectedDisplayIDs` set. If no match is found by the requested display UUID, it searches entries from displays whose UUID is *not* in the connected set (i.e., disconnected displays). This recovers names when a display's UUID changes.

### Disconnected display preservation (the merge)

`mergeSpaceNames()` combines the freshly computed `updatedNames` with `storedNames`. It preserves stored entries that aren't in `updatedNames` in two cases:

1. **Disconnected display**: The entry's `displayUUID` is not in the connected set. Always preserved — ensures disconnecting a monitor doesn't erase its names.

2. **Connected display with user data** (issue #22d): The entry has a non-empty name or color (`hasUserData`), its key isn't in `updatedNames` (macOS reassigned the ManagedSpaceID), AND no entry in `updatedNames` occupies the same display+position slot (the data hasn't migrated to a new key yet). This is a safety net: if position matching fails to recover the name (e.g., due to position corruption), the old entry survives for future recovery.

Note: when a space migrates from display A to display B (lid close), the same ManagedSpaceID appears in both `updatedNames` and `storedNames`. Because position preservation keeps the stored displayUUID (A) in `updatedNames`, and A is disconnected, the merge overwrites the entry from storedNames — but with identical data. The laptop entries retain their original display/position info, ready for when the laptop reconnects.

### The PreferencesViewModel overwrite bug

`PreferencesViewModel` only loads entries for currently active spaces (filtered by `AppDelegate.activeSpaceIDs`). Its `persistChanges()` and `updateSpaceColor()` must use `nameStore.update()` (not `save()`), which loads the existing store, merges in the changes, and writes back. Using `save()` would replace the entire store with only the active subset, permanently erasing disconnected display entries.

### Key files and their roles

| File | Role |
|------|------|
| `SpaceObserver.swift` | Owns `_needsPositionRevalidation`, `_lastKnownDisplayIDs`, and `_topologyChangeGracePeriod`, decides matching strategy per display, preserves positions for ID-matched entries during topology transitions, calls `resolveSpaceNameInfo` / `mergeSpaceNames` |
| `SpaceNameStore.swift` | Thread-safe persistence. `save()` replaces the entire store; `update()` merges into it. Callers that only have a subset of entries must use `update()`. |
| `PreferencesViewModel.swift` | Edits names/colors for active spaces only. Must use `nameStore.update()`, never `save()`. |
| `SpaceNameInfo.swift` | Value type. `displayUUID` and `positionOnDisplay` are the matching coordinates (may be preserved across topology changes). `currentDisplayIndex` and `currentSpaceNumber` reflect current state for UI display. `hasUserData` computed property indicates if the entry has a name or color. |

### Static methods on SpaceObserver (for testability)

The resolution logic lives in static methods so tests can call them without instantiating `SpaceObserver` (which requires a CG connection):

- `resolveSpaceNameInfo(managedSpaceID:displayID:position:storedNames:strategy:connectedDisplayIDs:)` — main entry point, delegates based on `SpaceNameMatchingStrategy`
- `findSpaceByPosition(in:displayID:position:connectedDisplayIDs:)` — position lookup with optional disconnected display fallback
- `mergeSpaceNames(updatedNames:storedNames:connectedDisplayIDs:)` — preserves disconnected display entries

### What to watch out for when modifying this code

1. **Never call `nameStore.save()` with a partial dictionary.** If you only have entries for some displays, use `nameStore.update()`. Otherwise you erase entries for disconnected displays.
2. **The revalidation flag must be set before the space change notification fires.** Wake sets the flag in `handleWake()`, which fires before the space-change notification. Display topology changes are detected separately in the worker queue by comparing `connectedDisplayIDs` against `_lastKnownDisplayIDs`.
3. **Position-only matching is reserved for wake/reboot.** Topology changes use `idWithPositionFallback`. Using position-only matching for topology changes causes name corruption because spaces migrate between displays and positions no longer correspond to the stored entries (issue #22b).
4. **`idWithPositionFallback` is safe for topology changes but NOT for wake/reboot with unchanged topology.** After reboot, IDs can swap (space 1 gets space 2's old ID), making ID matching give wrong results. The `_needsPositionRevalidation` flag ensures `.positionOnly` is used in that case — but only when the topology is unchanged. When wake and topology change happen together (e.g., sleep→mirror→wake), topology wins and `.idWithPositionFallback` is used, because positions are transient while the display reconfigures (issue #29).
5. **When ID matching succeeds during topology changes, preserve the stored displayUUID and positionOnDisplay.** Do not overwrite them with the current values. The current values are transient — if macOS assigns a new ID when the topology changes back, position matching must be able to find the entry at its original "home" position (issue #22c). Re-read the comparison table above if tempted to change this.
6. **The topology grace period (`_topologyChangeGracePeriod`) prevents position corruption from rapid updates.** After a topology change, macOS fires multiple notifications in quick succession. The first update correctly uses `.idWithPositionFallback` and preserves positions. Without the grace period, the second update would use `.idOnly` and overwrite the preserved position with the transient one (issue #22d). Do not remove the grace period without understanding this race condition.
7. **The merge preserves entries with user data even on connected displays.** This is a safety net for when position matching fails to recover a name after an ID reassignment. The entry sticks around under the old key until its display+position slot is claimed by a new entry. Do not simplify the merge to only check `connectedDisplayIDs` without also considering `hasUserData`.
8. **`findSpaceByPosition` with disconnected fallback is intentionally loose.** It matches any disconnected display at the same position. This is acceptable because it only triggers for display UUIDs with no stored entries, which means macOS gave the display a new identity.
