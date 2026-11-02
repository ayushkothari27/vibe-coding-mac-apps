import AppKit
import CoreText

/// Same palette and fonts as the vibe-coding web theme and Zeigarnik.
enum Theme {
    static let bg = NSColor(hex: 0x1A1A2E)
    static let orange = NSColor(hex: 0xC8572E)
    static let yellow = NSColor(hex: 0xC99A30)
    static let green = NSColor(hex: 0x3A8F72)
    static let pink = NSColor(hex: 0xB85C8A)
    static let indigo = NSColor(hex: 0x6366F1)
    static let muted = NSColor(hex: 0x9CA3AF)
    static let text = NSColor(hex: 0xF9FAFB)

    static func display(_ size: CGFloat) -> NSFont {
        guard let base = NSFont(name: "Fraunces", size: size) else { return .systemFont(ofSize: size, weight: .bold) }
        return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
    }

    static func accent(_ size: CGFloat) -> NSFont {
        guard let base = NSFont(name: "Fraunces", size: size) else { return .systemFont(ofSize: size) }
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
    }

    static func body(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: "Space Grotesk",
            .traits: [NSFontDescriptor.TraitKey.weight: weight],
        ])
        return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size, weight: weight)
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

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
