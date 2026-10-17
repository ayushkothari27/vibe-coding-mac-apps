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
                Text("Mind clear.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else if open.count > Self.maxVisible {
                ScrollView { rows(open) }
                    .frame(height: CGFloat(Self.maxVisible) * 62)
            } else {
                rows(open)
            }
        }
        .padding(12)
        .frame(width: 340)
        .background(ThemeBackground())
        .environment(\.colorScheme, .dark)
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
