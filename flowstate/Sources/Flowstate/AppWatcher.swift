import AppKit

/// Tracks when each app was last frontmost, so loops can resurface when you return to one.
@MainActor
final class AppWatcher {
    /// Called with the app and how long it had been since you last used it.
    var onAppActivated: ((NSRunningApplication, TimeInterval?) -> Void)?

    private var lastSeen: [String: Date] = [:]
    private var currentBundleID: String?

    func start() {
        currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.activated(app) }
        }
    }

    private func activated(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        let now = Date()
        if let previous = currentBundleID { lastSeen[previous] = now }
        currentBundleID = app.bundleIdentifier
        let away = app.bundleIdentifier.flatMap { lastSeen[$0] }.map { now.timeIntervalSince($0) }
        onAppActivated?(app, away)
    }
}
