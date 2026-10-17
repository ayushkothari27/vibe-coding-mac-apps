# vibecoded-mac-apps

Small native macOS apps, vibe-coded with Claude. Each one lives in its own folder and builds with just the Xcode Command Line Tools, no full Xcode needed.

## Apps

| App | Path | Description |
|-----|------|-------------|
| **Zeigarnik** | [`zeigarnik/`](zeigarnik/) | Menu bar app for parking "open loops" (Zeigarnik effect). Press ⌃⌥Space to offload a nagging thought; loops resurface when you return to the app you left them in. |

## Building

```sh
cd <app>
./build.sh
open build/<App>.app
```
