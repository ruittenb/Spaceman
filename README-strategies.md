# Space Switching Strategies

|               | **Click in icon**     | **Click in icon**         | **Menu option**       | **Menu option**            |
| ----          | ----                  | ----                      | ----                  | ----                       |
| **Scenario**  | Smooth (shortcuts)    | Fast / Instant (gestures) | Smooth (shortcuts)    | Fast / Instant (gestures)  |
| ----          | ----                  | ----                      | ----                  | ----                       |
| Desktop (has shortcut), same display | direct shortcut | gesture | direct shortcut | gesture |
| Desktop (has shortcut), cross-display | direct shortcut | ← fallback | direct shortcut | ← fallback |
| Desktop (no shortcut), same display | show configure balloon | gesture | chain from current; (or if shorter) gesture-jump to anchor, then chain; (or if no arrow shortcuts) unavailable/greyed out | gesture |
| Desktop (no shortcut), cross-display | show configure balloon | ← fallback | unavailable/greyed out | ← fallback |
| Fullscreen, same display | chain from current; (or if shorter) gesture-jump to anchor, then chain; (or if no arrow shortcuts) show "configure arrow shortcuts" | gesture | chain from current; (or if shorter) gesture-jump to anchor, then chain; (or if no arrow shortcuts) unavailable/greyed out | gesture |
| Fullscreen, cross-display | blink | ← fallback | unavailable/greyed out | ← fallback |

\* anchor = nearest desktop with a configured shortcut on the target display
