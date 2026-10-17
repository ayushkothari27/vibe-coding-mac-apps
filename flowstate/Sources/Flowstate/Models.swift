import Foundation

/// A thought you parked so your brain can stop rehearsing it (the Zeigarnik effect).
struct OpenLoop: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var created: Date
    var appName: String?
    var bundleID: String?
    var closed: Date?
}

enum Storage {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Flowstate", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}

extension TimeInterval {
    /// "1h 12m" / "34m"
    var shortDuration: String {
        let minutes = Int(self / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

/// Mutable view state. Stands in for SwiftUI's `@State`, whose macro plugin
/// only ships with full Xcode, not the Command Line Tools.
@Observable
final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}
