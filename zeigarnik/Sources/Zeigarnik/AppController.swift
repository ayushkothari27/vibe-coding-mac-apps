import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Captures loops via the global hotkey and resurfaces them when you return
/// to the app you parked them in.
@MainActor
final class AppController: NSObject {
    static let shared = AppController()

    /// How long you must have been away from an app before its loops resurface.
    static let returnThreshold: TimeInterval = 20 * 60
    static let toastLifetime: TimeInterval = 15

    let watcher = AppWatcher()
    let loops = LoopStore()

    private var hotKey: HotKey?
    private var capturePanel: FloatingPanel?
    private var toastPanel: FloatingPanel?
    private var toastTimer: Timer?
    private var statusItem: NSStatusItem?
    private var menuPanel: FloatingPanel?
    private var outsideClickMonitor: Any?

    func start() {
        Theme.registerFonts()
        watcher.onAppActivated = { [weak self] in self?.appReturned($0, away: $1) }
        watcher.start()
        setUpStatusItem()
        let env = ProcessInfo.processInfo.environment
        if let path = env["ZEIGARNIK_SNAPSHOT"] {
            DispatchQueue.main.async {
                if env["ZEIGARNIK_SNAPSHOT_VIEW"] == "menu" {
                    let panel = FloatingPanel(MenuView(loops: self.loops))
                    panel.orderFrontRegardless()
                    self.snapshot(panel, to: path)
                } else {
                    self.toggleCapture()
                }
            }
        }
        hotKey = HotKey(keyCode: kVK_Space, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggleCapture()
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath",
                                     accessibilityDescription: "Open loops")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    /// Left click shows loops; right click (or ⌃-click) shows a small menu with Quit.
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            toggleMenu()
        }
    }

    private func showContextMenu() {
        closeMenu()
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Zeigarnik", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // Attach only for this click so a normal left click still opens the loops panel.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func toggleMenu() {
        if menuPanel?.isVisible == true {
            closeMenu()
            return
        }
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let panel = FloatingPanel(MenuView(loops: loops))
        panel.onCancel = { [weak self] in self?.closeMenu() }
        // Centered under the icon, top edge pinned just below the menu bar, kept on screen.
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = (buttonWindow.screen ?? Self.screenWithMouse()).visibleFrame
        panel.place { size in
            let x = min(max(anchor.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
            return NSPoint(x: x.rounded(), y: anchor.minY - size.height - 6)
        }
        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)
        menuPanel = panel

        // Clicks in other apps dismiss it, like a real menu.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeMenu() }
        }
    }

    private func closeMenu() {
        menuPanel?.close()
        menuPanel = nil
        statusItem?.button?.highlight(false)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private static func screenWithMouse() -> NSScreen {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - Capture

    func toggleCapture() {
        if let panel = capturePanel, panel.isVisible {
            panel.close()
            return
        }
        let front = NSWorkspace.shared.frontmostApplication
        let app = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front

        var panel: FloatingPanel!
        panel = FloatingPanel(CaptureView(loops: loops) { [weak self] text in
            self?.loops.add(text, app: app)
            panel.close()
        })
        let screen = Self.screenWithMouse().visibleFrame
        panel.place { size in
            NSPoint(x: (screen.midX - size.width / 2).rounded(), y: (screen.midY - size.height / 2).rounded())
        }
        panel.makeKeyAndOrderFront(nil)
        capturePanel = panel
        if let path = ProcessInfo.processInfo.environment["ZEIGARNIK_SNAPSHOT"],
           ProcessInfo.processInfo.environment["ZEIGARNIK_SNAPSHOT_VIEW"] == nil {
            snapshot(panel, to: path)
        }
    }

    // MARK: - Resurfacing

    private func appReturned(_ app: NSRunningApplication, away: TimeInterval?) {
        guard let away, away >= Self.returnThreshold,
              let bundleID = app.bundleIdentifier else { return }
        let open = Array(loops.open(for: bundleID).prefix(5))
        guard !open.isEmpty else { return }
        showToast(title: "Back in", accent: app.localizedName ?? "this app",
                  subtitle: "You left these open \(away.shortDuration) ago", loops: open)
    }

    func showToast(title: String, accent: String, subtitle: String, loops open: [OpenLoop]) {
        toastPanel?.close()
        let panel = FloatingPanel(ToastView(title: title, accent: accent, subtitle: subtitle, loops: open,
                                            onClose: { [weak self] in self?.loops.close($0) },
                                            onDismiss: { [weak self] in self?.toastPanel?.close() }))
        let screen = Self.screenWithMouse().visibleFrame
        panel.place { size in NSPoint(x: screen.maxX - size.width - 16, y: screen.maxY - size.height - 16) }
        panel.orderFrontRegardless()
        toastPanel = panel

        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: Self.toastLifetime, repeats: false) { [weak panel] _ in
            MainActor.assumeIsolated { panel?.close() }
        }
    }

    /// Dev aid: ZEIGARNIK_SNAPSHOT=out.png renders the capture panel (or, with
    /// ZEIGARNIK_SNAPSHOT_VIEW=menu, the dropdown) to a PNG and quits.
    private func snapshot(_ panel: NSPanel, to path: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let view = panel.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            NSApp.terminate(nil)
        }
    }
}
