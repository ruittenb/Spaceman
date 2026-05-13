# Space Switching Strategies

|               | **Click in icon**     | **Click in icon**         | **Menu option**       | **Menu option**            |
| ----          | ----                  | ----                      | ----                  | ----                       |
| **Scenario**  | Smooth (shortcuts)    | Fast / Instant (gestures) | Smooth (shortcuts)    | Fast / Instant (gestures)  |
| ----          | ----                  | ----                      | ----                  | ----                       |
| Desktop (has shortcut), same display | direct shortcut | gesture | direct shortcut | gesture |
| Desktop (has shortcut), cross-display | direct shortcut | fallback to click icon/smooth | direct shortcut | fallback to menu option/smooth |
| Desktop (no shortcut), same display | show "configure space shortcuts" | gesture | chain from current; (or if shorter) gesture-jump to anchor, then chain; (or if no arrow shortcuts) unavailable/greyed out | gesture |
| Desktop (no shortcut), cross-display | show "configure space shortcuts" | fallback to click icon/smooth | shortcut-jump to anchor, then chain; (or if no anchor or no arrow shortcuts) unavailable/greyed out | fallback to menu option/smooth |
| Fullscreen, same display | chain from current; (or if shorter) gesture-jump to anchor, then chain; (or if no arrow shortcuts) show "configure arrow shortcuts" | gesture | chain from current; (or if shorter) gesture-jump to anchor, then chain; (or if no arrow shortcuts) unavailable/greyed out | gesture |
| Fullscreen, cross-display | shortcut-jump to anchor, then chain; (or if no anchor or no arrow shortcuts) show "configure arrow shortcuts" | fallback to click icon/smooth | shortcut-jump to anchor, then chain; (or if no anchor or no arrow shortcuts) unavailable/greyed out | fallback to menu option/smooth |

\* anchor = nearest desktop with a configured shortcut on the target display
