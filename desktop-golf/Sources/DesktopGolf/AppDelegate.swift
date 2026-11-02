import AppKit
import Carbon.HIToolbox

/// Menu bar icon, the ⌃⌥G hotkey, and showing or hiding the course overlay.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let game = Game()
    private var panel: OverlayPanel?
    private var view: GameView?
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var isPlaying: Bool { panel?.isVisible == true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        setUpStatusItem()
        hotKey = HotKey(keyCode: kVK_ANSI_G, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggle()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        show(newRound: true)

        if let path = ProcessInfo.processInfo.environment["GOLF_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.snapshot(to: path) }
        }
    }

    /// Opening the app again (Finder, Spotlight) starts or resumes a round.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show(newRound: false)
        return false
    }

    // MARK: - Overlay

    private func toggle() {
        isPlaying ? hide() : show(newRound: false)
    }

    /// Resumes an unfinished round unless asked for a fresh one.
    private func show(newRound: Bool) {
        guard let screen = NSScreen.screens.first else { return }
        if panel == nil {
            let panel = OverlayPanel(frame: screen.frame)
            let view = GameView(game: game, frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onClose = { [weak self] in self?.hide() }
            panel.contentView = view
            self.panel = panel
            self.view = view
            game.layout(for: screen)
            game.newRound()
        } else if newRound || game.phase == .finished {
            game.layout(for: screen)
            game.newRound()
        }
        panel?.orderFrontRegardless()
        view?.start()
    }

    private func hide() {
        view?.stop()
        panel?.orderOut(nil)
    }

    /// Display or Dock changes: refit the overlay and replay the current hole layout.
    private func screensChanged() {
        guard let panel, let view, let screen = NSScreen.screens.first else { return }
        panel.setFrame(screen.frame, display: false)
        view.frame = CGRect(origin: .zero, size: screen.frame.size)
        game.layout(for: screen)
        view.needsDisplay = true
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.golf", accessibilityDescription: "Desktop Golf")
            ?? NSImage(systemSymbolName: "flag.fill", accessibilityDescription: "Desktop Golf")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let toggleItem = NSMenuItem(title: isPlaying ? "Hide Course" : "Play", action: #selector(toggleFromMenu),
                                    keyEquivalent: "g")
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)
        let newRound = NSMenuItem(title: "New Round", action: #selector(newRoundFromMenu), keyEquivalent: "")
        newRound.target = self
        menu.addItem(newRound)
        menu.addItem(.separator())

        let best = game.bestToPar.map { "Best round: \(Game.formatToPar($0))" } ?? "No rounds finished yet"
        menu.addItem(NSMenuItem(title: best, action: nil, keyEquivalent: ""))
        if game.holesInOne > 0 {
            menu.addItem(NSMenuItem(title: "Holes in one: \(game.holesInOne)", action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Desktop Golf", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    @objc private func toggleFromMenu() { toggle() }
    @objc private func newRoundFromMenu() { show(newRound: true) }

    // MARK: - Testing

    /// GOLF_SNAPSHOT=out.png renders the overlay (on black) without needing screen recording.
    private func snapshot(to path: String) {
        guard let view else { return }
        let env = ProcessInfo.processInfo.environment["GOLF_SNAPSHOT_VIEW"]
        if env == "aim" || env == "shot" {
            // Pull back away from the cup at about 70% power.
            let away = (game.ball - game.cup).normalized * (Game.maxPull * 0.7)
            _ = game.beginAim(at: game.ball)
            game.aimPoint = game.ball + away
        }
        if env == "shot" {
            game.endAim()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                renderSnapshot(of: view, to: path)
            }
            return
        }
        renderSnapshot(of: view, to: path)
    }

    private func renderSnapshot(of view: GameView, to path: String) {
        // Draw straight into a flipped image over a dark backdrop, standing in for a desktop.
        let overlay = NSImage(size: view.bounds.size, flipped: true) { rect in
            view.draw(rect)
            return true
        }
        let image = NSImage(size: view.bounds.size, flipped: false) { rect in
            NSColor(white: 0.18, alpha: 1).setFill()
            rect.fill()
            overlay.draw(in: rect)
            return true
        }
        if let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }
}
