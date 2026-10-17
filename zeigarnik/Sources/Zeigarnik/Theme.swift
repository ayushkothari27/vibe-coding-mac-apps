import AppKit
import CoreText
import SwiftUI

/// Mirrors the vibe-coding web theme: navy background, drifting color blobs,
/// Fraunces for display type, Space Grotesk for everything else.
enum Theme {
    static let bg = Color(hex: 0x1A1A2E)
    static let orange = Color(hex: 0xC8572E)
    static let yellow = Color(hex: 0xC99A30)
    static let green = Color(hex: 0x3A8F72)
    static let pink = Color(hex: 0xB85C8A)
    static let indigo = Color(hex: 0x6366F1)
    static let purple = Color(hex: 0x7A5BB0)
    static let muted = Color(hex: 0x9CA3AF)
    static let text = Color(hex: 0xF9FAFB)
    static let surface = Color.white.opacity(0.05)
    static let surfaceHover = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.09)
    static let borderHover = Color.white.opacity(0.16)

    static func display(_ size: CGFloat) -> Font { .custom("Fraunces", size: size).weight(.bold) }
    static func accent(_ size: CGFloat) -> Font { .custom("Fraunces", size: size).italic() }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Space Grotesk", size: size).weight(weight)
    }

    /// Registers the fonts bundled in Contents/Resources/Fonts for this process only.
    static func registerFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for url in urls where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Navy backdrop with the template's soft blurred blobs, slowly drifting.
struct ThemeBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.bg
                blob(Theme.yellow, size: 300, x: 0.9, y: 0.0, t: t, period: 8)
                blob(Theme.pink, size: 260, x: 0.05, y: 1.0, t: t, period: 11)
                blob(Theme.indigo, size: 140, x: 0.7, y: 0.6, t: t, period: 7)
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat, t: Double, period: Double) -> some View {
        let phase = t.truncatingRemainder(dividingBy: period) / period * 2 * .pi
        return GeometryReader { geo in
            // Blobs are sized for a ~300pt-tall panel; shrink them for short ones.
            let scaled = size * min(1, geo.size.height / 300)
            // A radial gradient reads like the template's blur(90px) blob and is cheap to draw.
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.32), color.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: scaled / 2))
                .frame(width: scaled * 1.6, height: scaled * 1.6)
                .position(x: geo.size.width * x + 24 * sin(phase), y: geo.size.height * y + 16 * cos(phase))
        }
    }
}
