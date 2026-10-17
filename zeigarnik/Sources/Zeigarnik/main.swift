import AppKit

// Plain AppKit entry point: a SwiftUI `App` would need a scene, which shows up
// as an empty "Settings" window when the app is opened from Finder.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
