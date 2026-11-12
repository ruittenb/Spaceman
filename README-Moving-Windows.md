  The approaches in use (updated 2026-11-13, after the second, verified research round)

  ┌────────────────────────────────────────────────┬───────────────────────────────────┬────────────────────────────────────────────────────────┐
  │                    Approach                    │              Used by              │                         Status                         │
  ├────────────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 1. The old private calls                       │ Hammerspoon as released and on    │ Dead. Since 14.5 only the window's own app or the Dock │
  │ (SLSMoveWindowsToManagedSpace, the             │ master, older yabai               │ may move a window. On 15 and later, the calls report   │
  │  compat-ID trick)                              │                                   │ success and silently do nothing.                       │
  ├────────────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 2. The "bridged" operation                     │ yabai 7.1.25+, Loop, WhichSpace,  │ Works with SIP on, on 26.4+ for most people, but fails │
  │ (SLSBridgedMoveWindowsToManagedSpaceOperation) │ KiwiDesk, Floe, Dinky, ferry,     │ on some 26.4.1–26.6 machines (yabai #2789, cause       │
  │                                                │ spacemove, DockDoor ("bring here" │ unknown). macOS 27: one report says it works (27.0.1), │
  │                                                │ only), Hammerspoon's open fix     │ another says it is ignored: unresolved. The class      │
  │                                                │ (PR #3889), Spaceman (new branch) │ exists since 14.5; moves on 15 and 26.0–26.3 are       │
  │                                                │                                   │ untested.                                              │
  ├────────────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 3. The drag trick (title bar + Mission Control │ Paulo's code, Amethyst,           │ Works everywhere, but is flaky. BetterTouchTool users  │
  │ shortcut)                                      │ BetterTouchTool, Rectangle Pro    │ report the same JetBrains and Slack failures you saw.  │
  │                                                │                                   │ Floe and Loop dropped it in favour of approach 2.      │
  ├────────────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 4. Faking workspaces instead of using Spaces   │ AeroSpace, FlashSpace, Rift,      │ Hidden windows are parked just off-screen. Not usable  │
  │                                                │ OmniWM, GlazeWM, komorebi         │ for Spaceman, which is all about native Spaces.        │
  ├────────────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 5. Dragging the window's thumbnail in Mission  │ PaperWM.spoon (PR #174)           │ Reported on 27. Mission Control opens visibly during   │
  │ Control                                        │                                   │ the move.                                              │
  ├────────────────────────────────────────────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 6. Staging the window via a virtual display    │ cubicle                           │ Reported on 27, based on a single test.                │
  └────────────────────────────────────────────────┴───────────────────────────────────┴────────────────────────────────────────────────────────┘

  A correction to the first round: the "Hammerspoon solution" as it currently ships (approach 1, also on master) no longer works on 15
  and later. Only its open fix (PR #3889), which uses approach 2, does.

  How the bridged operation works

  Spaceman asks SkyLight, which passes the move on to the Dock. The Dock is allowed to move any window, so this works with SIP on. It
  never moves the pointer and doesn't care about title bars, so iTerm2, Slack, Brave and IntelliJ should work (not yet tested here).

  In Swift it takes roughly these steps, the way KiwiDesk, spacemove and Loop do it:
  1. Get the window number of the focused window, using Accessibility plus the private _AXUIElementGetWindow.
  2. Get the ID of the space to its left or right from CGSCopyManagedDisplaySpaces, which Spaceman already calls.
  3. Create the move operation (NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation"), initWithWindows:spaceID:) and send it
     performWithWMBridgeDelegate.
  4. Confirm the move with CGSCopySpacesForWindows. The call is asynchronous and its return value means nothing.
  5. Optionally, switch to the target space with Spaceman's existing switching code and bring the window to the front.

  It needs AppKit to be loaded (ferry README, KiwiDesk #884) and Accessibility permission; Spaceman has both. Whether it needs an
  entitlement or a Developer ID: no source says either way.

  What Spaceman does (branch feature/bridged-switching)

  - ⌃⌥⌘← / ⌃⌥⌘→ move the focused window to the previous or next space on the window's own display. Full-screen spaces are skipped.
  - After the move, Spaceman checks every 15 ms, for at most 0.5 s, whether the window really arrived. If not, it shows an error.
  - When it did arrive, Spaceman follows it to the target space and brings it to the front.
  - Full-screen windows and windows shown on all spaces can't be moved; Spaceman says so.
  - The drag trick has been removed completely.
  - Failures are logged in Console.app under the category "windowMove".

  Caveats

  - It's confirmed only on 26.4 and later, and even there it fails on some machines (yabai #2789). macOS 27 is unresolved. The class
    exists from 14.5 on, but moves on Sequoia and on 26.0–26.3 are untested. Spaceman's check turns a silent failure into an error.
  - Moves to and from full-screen spaces are rejected.
  - Setups with several displays have hardly been tested.
  - When yabai moves a window and then switches to it, the window sometimes doesn't get focus (yabai issue #2801).
  - It's private API, so a new macOS version may break it again, just as with CGSCopyManagedDisplaySpaces.

---

  Test results (2026-11-13)

  - Tested by René on macOS 26.5.1, on branch feature/bridged-switching: moving the focused window to the previous and next space
    works.
  - Not tested yet: macOS 15, 26.0–26.3 and 27; setups with several displays.

  Evaluation

  What's good:
  - It fills a real gap. Apart from dragging, macOS offers no good way to move a window to another space.
  - It doesn't move the pointer and doesn't depend on title bars, unlike the drag trick.
  - A failed move shows an error instead of silently doing nothing.
  - The behaviour is predictable: it stays on the window's own display, skips full-screen spaces and follows the window.

  The doubts:
  - It's fragile. It's confirmed only on 26.4 and later, and fails on some machines even there (yabai #2789). Apple already closed
    the previous method in 14.5 and can close this one too, so the feature may disappear with a single macOS update.
  - It only half fits Spaceman. Spaceman shows and switches spaces; moving windows is a step towards a window manager, and invites
    requests such as "move to space N", "move to another display" or "move several windows".

  Workaround: Start dragging a window, then use the shortcut key to switch to a different space.

  Decision: parked. It works, but releasing a feature that the next macOS version may break for good is not worth it for now. The
  code stays on feature/bridged-switching. If it's picked up again: offer it as opt-in (shortcuts empty by default), mark it as
  experimental in the README, and test it on the then-current macOS version first.

