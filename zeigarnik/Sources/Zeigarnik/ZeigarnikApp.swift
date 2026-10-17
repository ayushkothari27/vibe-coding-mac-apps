import SwiftUI

@main
struct ZeigarnikApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        // The menu bar item and panels are managed in AppKit by AppController,
        // so their placement can be controlled exactly.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppController.shared.start() }
    }
}

/// The dropdown: open loops as themed cards. Click the circle to close one, × to delete.
struct MenuView: View {
    let loops: LoopStore
    private let hovered = Box<UUID?>(nil)
    static let maxVisible = 6

    var body: some View {
        let open = loops.open
        VStack(alignment: .leading, spacing: 8) {
            if open.isEmpty {
                emptyState
            } else {
                if open.count > Self.maxVisible {
                    ScrollView { rows(open) }
                        .frame(height: CGFloat(Self.maxVisible) * 62)
                } else {
                    rows(open)
                }
                ShortcutHint()
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(width: 340)
        .background(ThemeBackground())
        .environment(\.colorScheme, .dark)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mind \(Text("clear").font(Theme.accent(22)).foregroundStyle(Theme.yellow))")
                .font(Theme.display(22))
                .foregroundStyle(Theme.text)
            Text("Unfinished tasks keep looping in your head until they're written down somewhere you trust. Park them here and let go.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ShortcutHint()
                .padding(.top, 4)
        }
        .padding(8)
    }

    private func rows(_ open: [OpenLoop]) -> some View {
        VStack(spacing: 8) {
            ForEach(open) { loop in
                LoopRow(loop: loop, hovered: hovered,
                        onClose: { withAnimation(.easeOut(duration: 0.2)) { loops.close(loop.id) } },
                        onDelete: { withAnimation(.easeOut(duration: 0.2)) { loops.delete(loop.id) } })
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }
}

/// "⌃ ⌥ Space  to park a thought", drawn as keycaps.
struct ShortcutHint: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(["⌃", "⌥", "Space"], id: \.self) { key in
                Text(key)
                    .font(Theme.body(11, .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 20)
                    .background(Theme.surfaceHover, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.borderHover))
            }
            Text("to park a thought")
                .font(Theme.body(11))
                .foregroundStyle(Theme.muted)
                .padding(.leading, 4)
        }
    }
}
