
![Spaceman Example](images/Header.png)

## About

Spaceman is an application for macOS that allows you to view your Spaces / Virtual Desktops in the menu bar. Spaceman allows you to see which space you are currently on (or spaces if you are using multiple displays) relative to the other spaces you have. Naming these spaces is also an option in order to organise separate spaces for your workflow.

Also, the menu and statusbar icons enable switching between spaces.

**Spaceman requires macOS 11 Big Sur or greater.**

## Install

### GitHub

Go to the [releases](https://github.com/ruittenb/Spaceman/releases) tab and download **Spaceman.dmg** from the latest release.

## Usage

<img src="images/Spaceman_Example.png" width="66%" height="auto">

The above image shows the possible icons that you will see depending on the style you choose.

There are five icon styles to choose from, from top to bottom:
- Rectangles
- Numbers
- Rectangles with Numbers
- Names
- Names with Numbers

The meaning of the icons from left to right are:

- Active Space
- Inactive Space
- Inactive Fullscreen App
- Gap (The gap denotes that the spaces that follow are on a different display)
- Inactive Space
- Active Fullscreen App

## Preferences

<img src="images/Preferences-4a.png" width="66%" height="auto">

The style and the name of a space can be changed in preferences (shown above). A space is named by selecting the space from the dropdown and editing its name (up to 4 characters).

If the icon fails to update, you can choose to force a refresh of the icon using a custom keyboard shortcut or allow Spaceman to refresh them automatically every 5 seconds by enabling 'Refresh spaces in background'.

### Switching Spaces

Icons in the status bar can be clicked to switch spaces:

<img src="images/Switching-Spaces.gif" width="66%" height="auto">

The menu shows a list of space names. Selecting one will cause Spaceman to switch to that space.

<img src="images/Menu.png" width="auto" height="auto">

Spaceman switches spaces by sending a keyboard shortcut to System Events using Applescript.

The first ten non-fullscreen spaces will have shortcut keys 0-9 assigned.

The first two fullscreen spaces will have keyboard shortcuts, but these are not recognized
by Mission Control. For making use of these, you would have to use an application like
[Apptivate](http://www.apptivateapp.com/).

For extra spaces, switching will not be available; the status bar icon will flash if
selected, and the menu option will be disabled.


**For switching to work successfully, the following things need to be configured:**

- Spaceman needs authorization for Accessibility:

<img src="images/Accessibility-1.png" width="66%" height="auto">
<img src="images/Accessibility-2.png" width="66%" height="auto">

- Shortcut keys need to have been defined for Mission Control:

<img src="images/Shortcuts.png" width="66%" height="auto">

- Spaceman needs to know which shortcuts to send:

<img src="images/Preferences-4b.png" width="66%" height="auto">

## Remote Refresh

The list of spaces can also be refreshed using Applescript:

```sh
$ osascript -e 'tell application "Spaceman" to refresh'
```

For details on how to maximize usefulness of this, see [MikeJL's Comments](README-Yabai.md)

## Troubleshooting

If Spaceman does not start, or does not run correctly, after an upgrade:
you may need to delete the application defaults:

```sh
$ defaults delete dev.ruittenb.Spaceman
```

## Attributions

- This project is based on [WhichSpace](https://github.com/gechr/WhichSpace)
- This project uses [Sparkle](https://sparkle-project.org) for update delivery
- This project makes use of [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin)
- This project makes use of [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- Authors:
  - [Sasindu Jayasinghe](https://github.com/Jaysce/Spaceman)
  - [René Uittenbogaard](https://github.com/ruittenb/Spaceman)
- Contributions by:
  - [Waylon Wang](https://github.com/waylonwang/Spaceman)
  - [ultravioletcatastrophe](https://github.com/ultravioletcatastrophe/Spaceman)
  - [Dmitry Poznyak](https://github.com/triangular-sneaky/Spaceman)
  - [Grzegorz Milka](https://github.com/gregorias/Spaceman)
  - [Michael Lehenauer](https://github.com/mike-jl/Spaceman)
  - [Logan Savage](https://github.com/lxsavage/Spaceman)
  - [Yakir Lugasy](https://github.com/yakirlog/Spaceman)
  - [aaplmath](https://github.com/aaplmath)

## Mentions

- [Softpedia](https://mac.softpedia.com/get/System-Utilities/Spaceman.shtml)


