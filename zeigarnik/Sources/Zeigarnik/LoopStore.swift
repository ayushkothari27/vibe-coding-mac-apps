import AppKit
import Observation

@MainActor @Observable
final class LoopStore {
    private(set) var loops: [OpenLoop] = []
    private static let file = "loops.json"

    var open: [OpenLoop] {
        loops.filter { $0.closed == nil }.sorted { $0.created > $1.created }
    }

    init() {
        loops = Storage.load([OpenLoop].self, from: Self.file) ?? []
        // Keep closed loops around for a month, then let them go.
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        loops.removeAll { ($0.closed ?? .distantFuture) < cutoff }
    }

    func add(_ text: String, app: NSRunningApplication?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        loops.append(OpenLoop(text: trimmed, created: Date(),
                              appName: app?.localizedName, bundleID: app?.bundleIdentifier))
        persist()
    }

    func close(_ id: UUID) {
        guard let i = loops.firstIndex(where: { $0.id == id }) else { return }
        loops[i].closed = Date()
        persist()
    }

    func delete(_ id: UUID) {
        loops.removeAll { $0.id == id }
        persist()
    }

    func open(for bundleID: String) -> [OpenLoop] {
        open.filter { $0.bundleID == bundleID }
    }

    private func persist() {
        Storage.save(loops, to: Self.file)
    }
}
