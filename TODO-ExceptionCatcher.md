# Plan: Add ExceptionCatcher for Private API Resilience

## Context

Spaceman uses private Core Graphics APIs (`_CGSDefaultConnection`, `CGSCopyManagedDisplaySpaces`) to read space/display information. These undocumented APIs could throw Objective-C exceptions if macOS changes their behavior in future versions. Swift's standard error handling cannot catch ObjC exceptions — they crash the app. ExceptionCatcher bridges this gap.

Currently:
- `_CGSDefaultConnection()` at SpaceObserver.swift:29 has **no error handling**
- `CGSCopyManagedDisplaySpaces()` at SpaceObserver.swift:387 has nil-checking but **no ObjC exception protection**

## Implementation

### 1. Add ExceptionCatcher dependency

In Xcode: File → Add Package Dependencies → `https://github.com/sindresorhus/ExceptionCatcher`

### 2. Wrap the connection initialization

**File:** `Spaceman/Helpers/SpaceObserver.swift`

Change line 29 from:
```swift
private let conn = _CGSDefaultConnection()
```

To a lazy initialization with exception catching:
```swift
private var conn: Int32 = 0
private var connectionFailed = false
private let logger = Logger(subsystem: Constants.AppInfo.bundleId, category: "SpaceObserver")

private func ensureConnection() -> Bool {
    if connectionFailed { return false }
    if conn != 0 { return true }
    
    do {
        conn = try ExceptionCatcher.catch {
            _CGSDefaultConnection()
        }
        return conn != 0
    } catch {
        logger.error("CGS connection failed: \(error.localizedDescription)")
        connectionFailed = true
        return false
    }
}
```

### 3. Wrap the display spaces fetch

**File:** `Spaceman/Helpers/SpaceObserver.swift`

Modify `fetchDisplaySpaces()` (around line 383):
```swift
private func fetchDisplaySpaces() -> [NSDictionary]? {
    if let provider = displaySpacesProvider {
        return provider()
    }
    guard ensureConnection() else { return nil }
    
    do {
        let rawDisplays = try ExceptionCatcher.catch {
            CGSCopyManagedDisplaySpaces(self.conn)?.takeRetainedValue() as? [NSDictionary]
        }
        return rawDisplays
    } catch {
        logger.error("CGSCopyManagedDisplaySpaces failed: \(error.localizedDescription)")
        return nil
    }
}
```

### 4. Add import statements

At top of SpaceObserver.swift (after `import Foundation`):
```swift
import ExceptionCatcher
import os.log
```

## Files to Modify

- `Spaceman.xcodeproj/project.pbxproj` — package dependency (via Xcode UI)
- `Spaceman/Helpers/SpaceObserver.swift` — wrap API calls

## Verification

1. Build the project in Xcode
2. Run the app — spaces should display normally
3. Check Console.app for any "CGS connection failed" or "CGSCopyManagedDisplaySpaces failed" log messages (there should be none on current macOS)
4. Run existing tests: `xcodebuild test -project Spaceman.xcodeproj -scheme Spaceman -destination platform=macOS`
