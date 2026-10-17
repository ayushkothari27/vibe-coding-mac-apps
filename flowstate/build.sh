#!/bin/bash
# Builds Flowstate.app into ./build (no Xcode required).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/Flowstate.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Flowstate "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/Fonts "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"
