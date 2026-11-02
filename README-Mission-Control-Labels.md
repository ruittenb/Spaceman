# Mission Control Labels

## The Problem

macOS Mission Control displays spaces as "Desktop 1", "Desktop 2", etc. There is no way to rename these captions — not in System Settings, not via AppleScript, not through any public API. This has been the most-requested Mission Control feature since 2011, with thousands of votes in Apple Community threads. As of macOS 27, it remains unsupported.

## Strategies Considered

### 1. Native API

**Does not exist.** There is no public or private API to rename Mission Control captions.

The SkyLight framework has `SLSSpaceCopyName`, but it returns the space's UUID — the internal identifier macOS uses to track the space. There is no `SLSSpaceSetName`. Changing the UUID would break every link macOS keeps to that space.

The `com.apple.spaces.plist` file contains space UUIDs and visual order, but no user-facing name field. Adding one has no effect — Mission Control generates "Desktop N" labels at runtime based on position.

### 2. DYLD Injection

**Requires SIP disabled — ruled out.**

This approach loads a dylib into WindowManager (macOS 27) or Dock (older) to hook the label-drawing function and rewrite "Desktop 1" to a custom name. The labels are modified at the source — no overlay windows needed.

Tools using this approach:
- [spaces-renamer (Quelaan1)](https://github.com/Quelaan1/spaces-renamer) — modern fork for macOS 26/27

Requirements:
- System Integrity Protection disabled or reduced
- `arm64e_preview_abi` boot argument on Apple Silicon
- Both require Recovery Mode boot

Risks:
- macOS updates silently drop boot arguments
- Corrupt injector can require Recovery boot to fix
- Apple can close this loophole at any time

**Conclusion:** Unacceptable for a user-facing app. Users should not disable SIP.

### 3. Vision OCR + Screen Capture

**Too invasive — ruled out.**

This approach captures the screen where Mission Control draws, uses Apple's Vision framework to locate "Desktop N" text via OCR, then draws overlay windows at those positions.

Tool using this approach:
- [MySpaces](https://github.com/jozeta/MySpaces)

Requirements:
- Screen Recording permission (in addition to Accessibility)
- Polls up to 60× per second against pixel fingerprint

**Conclusion:** Screen Recording permission is a significant privacy ask. The approach is also fragile — depends on OCR accuracy and pixel matching.

### 4. Menu Bar Only (No Mission Control)

**Does not solve the problem.**

Some apps show space names only in the menu bar, explicitly stating they cannot show labels in Mission Control.

- [Desktop Space Renamer](https://apps.apple.com/us/app/desktop-space-renamer/id6745852577) (App Store)

Their own description: "The small desktop labels don't appear in the Mission Control screen — Apple doesn't allow this."

### 5. Accessibility API + Overlay

**The least invasive approach.**

This is what many successful Mission Control labeling apps use:

1. Poll for Mission Control being open (no notifications exist)
2. Read thumbnail positions via the Accessibility tree
3. Draw click-through windows with custom labels over the captions

Tools using this approach:
- [ActiveSpace](https://github.com/PerpetualBeta/ActiveSpace)
- [SpaceNames](https://github.com/jrp-git/SpaceNames)
- [SpaceJump](https://www.getspacejump.com/) (commercial)
- [MacSpaceLabeler](https://github.com/JohnSparham/MacSpaceLabeler) (original, macOS 26)

Requirements:
- Accessibility permission only
- Works with SIP enabled
- No screen capture needed

## Why Polling?

No notification fires when Mission Control opens or closes. Tested and confirmed silent on macOS 27:

- AXObserver notifications (AXCreated, AXUIElementDestroyed, AXFocusedUIElementChanged)
- Dock Expose notifications (AXExposeShowAllWindows, AXExposeShowDesktop, AXExposeExit)
- Distributed/Darwin notifications (com.apple.expose.awake, etc.)

Default poll interval: 250ms (4× per second). Cost: ~0.1% CPU while enabled.

## How It Works

### Accessibility Tree Structure

**macOS 27+:** The Spaces Bar lives in `com.apple.WindowManager`:

```
AXApplication "WindowManager"
  AXGroup id=mc.display              (one per display)
    AXGroup "Spaces Bar" id=mc.spaces
      AXList id=mc.spaces.list
        AXButton "Desktop 1"         (one per space)
```

**macOS 26 and earlier:** The Spaces Bar was in `com.apple.dock` under a "Mission Control" AXGroup.

### Overlay Windows

```swift
level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
ignoresMouseEvents = true
collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
```

### Coordinate Conversion

AX coordinates have origin at top-left of primary display. AppKit has origin at bottom-left:

```swift
func appKitPoint(fromAX point: CGPoint) -> CGPoint {
    let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
    return CGPoint(x: point.x, y: primaryTop - point.y)
}
```

### macOS 27 Quirk

The AX "position" of each Spaces Bar button is the thumbnail's CENTER, not top-left. The caption sits ~53pt below this center.

### Multi-Display with Shared Spaces

When "Displays have separate Spaces" is off, WindowManager exposes only one Spaces Bar but draws copies on all displays. The overlay mirrors labels to other screens by calculating the offset from the primary bar's center.

## Conclusion

If we want to show custom space names in Mission Control without:
- Disabling SIP
- Requesting Screen Recording permission

Then there is one approach: **Poll the Accessibility tree. Draw overlay windows.**

This requires only Accessibility permission — the same permission Spaceman already needs for space switching.

## Implementation

Spaceman's implementation: `Spaceman/Helpers/MissionControlLabels.swift`

Adapted from ActiveSpace, which credits MacSpaceLabeler.

## References

- [ActiveSpace](https://github.com/PerpetualBeta/ActiveSpace)
- [SpaceNames](https://github.com/jrp-git/SpaceNames)
- [MacSpaceLabeler](https://github.com/JohnSparham/MacSpaceLabeler)
- [MySpaces](https://github.com/jozeta/MySpaces)
- [spaces-renamer](https://github.com/Quelaan1/spaces-renamer)
- [SpaceJump](https://www.getspacejump.com/)
- [DYLD injection deep dive](https://theevilbit.github.io/posts/dyld_insert_libraries_dylib_injection_in_macos_osx_deep_dive/)
- [MIP - Managed Injection Platform](https://github.com/LIJI32/MIP)
