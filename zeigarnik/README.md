# Zeigarnik

A macOS menu bar app named after the **Zeigarnik effect**: unfinished tasks keep nagging at your mind until they're written down somewhere you trust. Zeigarnik gives those "open loops" a place to go in two seconds, so you can get back to what you were doing.

## Usage

| | |
|---|---|
| **⌃⌥Space** | Opens the capture popup in the center of the screen. Type the thought, press ↩ to park it, esc to close. Your open loops are listed underneath. |
| **↻ in the menu bar** | Shows your open loops right under the icon. Click outside or press esc to close. |
| **○** | Closes a loop (marks it done). |
| **×** (on hover) | Deletes a loop. |

Loops also resurface on their own. Each one remembers which app you parked it in, and if you return to that app after 20+ minutes away, its loops pop up in the top-right corner.

## Design

The UI follows the [vibe-coding](https://github.com/ayushkothari27/vibe-coding) web theme: navy `#1A1A2E` background with soft drifting color blobs, Fraunces for display type, and Space Grotesk for everything else. Both fonts are bundled in `Resources/Fonts` (SIL Open Font License) and registered at launch, so nothing needs installing.

## Build

Needs only the Xcode Command Line Tools; full Xcode isn't required. macOS 14+.

```sh
./build.sh
open build/Zeigarnik.app
```

To keep it around, copy `build/Zeigarnik.app` to `/Applications`. Add it under **System Settings → General → Login Items** to start it at login.

Because the Command Line Tools don't ship SwiftUI's macro plugin, the code avoids `@State` and uses a small `@Observable` `Box` class instead. The global hotkey uses Carbon's `RegisterEventHotKey`, so no Accessibility permission is needed.

## Data

Everything stays on your Mac, in `~/Library/Application Support/Zeigarnik/loops.json`. Closed loops are pruned after 30 days.

## Project layout

```
Sources/Zeigarnik/
  ZeigarnikApp.swift    app entry + menu dropdown view
  AppController.swift   status item, hotkey, panel placement, resurfacing
  AppWatcher.swift      tracks when each app was last frontmost
  LoopStore.swift       loop persistence
  Panels.swift          capture popup, loop cards, toast
  Theme.swift           colors, fonts, blob background
  HotKey.swift          Carbon global hotkey
  Models.swift          OpenLoop, Box, JSON storage
```

Dev aid: `ZEIGARNIK_SNAPSHOT=out.png ./build/Zeigarnik.app/Contents/MacOS/Zeigarnik` renders the capture popup to a PNG and quits. Add `ZEIGARNIK_SNAPSHOT_VIEW=menu` to render the dropdown instead.
