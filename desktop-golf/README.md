# Desktop Golf

Mini golf played on your actual desktop. Your windows are the walls, the Dock is a bunker, and moving a window reshapes the course mid-hole.

## Install (about 2 minutes)

1. `cd desktop-golf`
2. `./build.sh`
3. `open build/DesktopGolf.app`

Needs macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode isn't required.

## Play

| Action | What happens |
|---|---|
| **Drag back from the ball, let go** | Shoots. Pull farther for more power; the dotted line shows direction. |
| **Move or resize any window** | The course changes instantly, even while the ball is rolling. |
| **⌃⌥G** | Hide or show the course. A round in progress is kept. |
| **esc** | Hide the course (after you've clicked the ball once). |
| **Menu bar ⛳** | Play, New Round, your best score, Quit. |

- **Walls:** the visible edges of your windows (green lines). Edges hidden behind another window don't count.
- **Sand:** the Dock strip and one oval trap per hole. The ball slows down hard in it.
- **Cup:** roll in gently. A fast ball lips out; a slow one near the cup curls in.
- **Par:** 2–4 by distance, +1 if a window blocks the straight line.
- **Round:** 9 holes. Your best score (vs. par) is saved.

The rest of your screen keeps working while you play. Clicks only go to the game when the cursor is on the ball.

## Your data

- Best score and hole-in-one count live in the app's UserDefaults (`com.ayushkothari.desktopgolf`).
- No network access and no permissions requested. Window positions are read with `CGWindowListCopyWindowInfo`, which doesn't need Screen Recording permission since it never reads window contents or titles.

## For developers

| File | Job |
|---|---|
| `AppDelegate.swift` | Menu bar icon, ⌃⌥G hotkey, showing and hiding the overlay |
| `Game.swift` | Holes, ball physics, cup, scoring |
| `Course.swift` | Reading window frames and turning their visible edges into walls |
| `GameView.swift` | Transparent overlay panel, drawing, mouse input, click-through |
| `Theme.swift` / `HotKey.swift` / `main.swift` | Colors and fonts, global hotkey, AppKit entry point |

- **Click-through:** the overlay ignores the mouse except within 40pt of the ball, so your windows stay usable.
- **Screenshot without clicking:** `GOLF_SNAPSHOT=out.png build/DesktopGolf.app/Contents/MacOS/DesktopGolf` (add `GOLF_SNAPSHOT_VIEW=aim` or `shot` to show aiming or a shot in progress)
