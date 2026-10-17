# Zeigarnik

Park a nagging thought in 2 seconds: press **⌃⌥Space**, type it, hit **↩**.

A macOS menu bar app named after the **Zeigarnik effect**: unfinished tasks keep looping in your head until they're stored somewhere you trust.

## Install (about 2 minutes)

1. `cd zeigarnik`
2. `./build.sh`
3. `open build/Zeigarnik.app`

Needs macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode isn't required.

## Use it

| Action | What happens |
|---|---|
| **⌃⌥Space** | Capture popup opens in the center of the screen. Your open loops are listed below the text box. |
| **↻ in the menu bar** | Open loops appear under the icon. |
| **○** | Closes a loop (marks it done). |
| **×** (on hover) | Deletes a loop. |
| **esc** or click outside | Dismisses the popup or menu. |
| **Right-click ↻** | Quit Zeigarnik. |

Loops come back on their own: return to an app after 20+ minutes away, and the loops you parked there pop up top-right.

## Keep it running

1. Copy `build/Zeigarnik.app` to `/Applications`
2. Add it in **System Settings → General → Login Items**

## Your data

- Stored only on your Mac: `~/Library/Application Support/Zeigarnik/loops.json`
- No network access and no permissions requested
- Closed loops are deleted after 30 days

To uninstall: right-click ↻ → Quit, then delete the app and that folder.

## For developers

| File | Job |
|---|---|
| `AppController.swift` | Menu bar icon, hotkey, panel placement, resurfacing |
| `Panels.swift` | Capture popup, loop cards, toast |
| `Theme.swift` | Colors, fonts, background blobs |
| `LoopStore.swift` / `Models.swift` | Saving loops as JSON |
| `HotKey.swift` / `AppWatcher.swift` | Global hotkey, frontmost-app tracking |

- **Theme:** matches [vibe-coding](https://github.com/ayushkothari27/vibe-coding): navy `#1A1A2E`, Fraunces + Space Grotesk (bundled, OFL)
- **No `@State`:** the Command Line Tools lack SwiftUI's macro plugin, so view state uses an `@Observable` `Box`
- **Screenshot without clicking:** `ZEIGARNIK_SNAPSHOT=out.png build/Zeigarnik.app/Contents/MacOS/Zeigarnik` (add `ZEIGARNIK_SNAPSHOT_VIEW=menu` for the dropdown)
