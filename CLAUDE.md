# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Spaceman is a macOS application that displays macOS Spaces/Virtual Desktops in the menu bar. It's built with Swift and SwiftUI, using Xcode as the primary development environment.

## Build Commands

**Build the archive:**
```bash
make build
# or directly:
xcodebuild -workspace Spaceman.xcodeproj/project.xcworkspace -scheme Spaceman -configuration Release clean archive -archivePath build/Spaceman.xcarchive
```

**Export the app:**
```bash
make export
```

**Create DMG installer:**
```bash
make image
```

**Build everything:**
```bash
make all
```

**Clear application defaults (for troubleshooting):**
```bash
make defaults-clear
```

**View stored defaults:**
```bash
make defaults-get
```

## Core Architecture

The application follows a delegate pattern with these key components:

### Main Components
- **AppDelegate**: Entry point that initializes core components and handles keyboard shortcuts
- **StatusBar**: Manages the menu bar item, handles clicks, and creates menus
- **SpaceObserver**: Monitors macOS space changes using Core Graphics APIs
- **IconCreator**: Generates status bar icons based on space configuration
- **SpaceSwitcher**: Handles switching between spaces via AppleScript

### Data Models
- **Space**: Core data structure representing a macOS space with display info, names, and states
- **SpaceNameInfo**: Cached space name information
- **DisplayStyle**: Enumeration of icon display styles (rectangles, numbers, names, etc.)

### Key Dependencies
- **Sparkle**: Auto-updating framework
- **KeyboardShortcuts**: Keyboard shortcut management
- **LaunchAtLogin**: Launch at login functionality

## macOS Integration

The app uses private Core Graphics APIs to monitor spaces:
- `CGSCopyManagedDisplaySpaces()` - Gets space information
- `_CGSDefaultConnection()` - Connection to window server
- AppleScript for space switching via Mission Control shortcuts

## File Structure

- `Spaceman/` - Main source code
  - `Helpers/` - Utility classes (SpaceObserver, IconCreator, etc.)
  - `Model/` - Data models and enums
  - `View/` - SwiftUI views and UI components
  - `ViewModel/` - View models and business logic
  - `Utilities/` - Constants and utilities
- `Spaceman.xcodeproj/` - Xcode project configuration
- `build/` - Build output directory
- `website/` - Project website files

## Website Deployment

**Publish website changes:**
```bash
make publish
```

## Code Signing

This project does not have a developer certificate, so no code signing or notarization takes place.

## Testing

The project includes unit tests for data models and core business logic.

**Run tests from command line:**
```bash
xcodebuild test -project Spaceman.xcodeproj -scheme Spaceman -destination platform=macOS
```

**Test structure:**
- `SpacemanTests/SpaceTests.swift` - Tests for the Space model
- `SpacemanTests/SpaceNameInfoTests.swift` - Tests for SpaceNameInfo (including Codable/Hashable)
- `SpacemanTests/DisplayStyleTests.swift` - Tests for DisplayStyle enum
- `SpacemanTests/SpaceFilterTests.swift` - Tests for space filtering logic

**What's tested:**
- Data model initialization and properties
- Enum raw values and CaseIterable conformance
- Codable/Hashable protocol conformance
- Space filtering logic for different visibility modes:
  - All spaces mode
  - Current space only mode
  - Neighbor spaces mode with different radius values
  - Multi-display scenarios
  - Edge cases (first/last space, empty states)

**What's not tested:**
- UI components (menu bar, preferences window)
- System integration (private macOS APIs, AppleScript)
- Icon generation (NSImage manipulation)
