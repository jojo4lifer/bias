import Foundation

/// A visual theme. Everything is procedural — gradients and type — so the app ships no image
/// assets, stays tiny, and has no third-party image rights to worry about.
public struct ThemeSpec: Identifiable, Hashable, Sendable {
    public let id: String
    /// Key into the String Catalog. Never display this raw value.
    public let nameKey: String
    /// Two or three hex stops, applied top-left to bottom-right.
    public let hexStops: [String]
    public let angleDegrees: Double
    /// Hex of the text colour to use on this theme.
    public let textHex: String
    public let fontDesign: FontDesign
    public let isFreeForAll: Bool

    public enum FontDesign: String, Sendable {
        case serif
        case standard
        case rounded
    }

    public init(
        id: String,
        nameKey: String,
        hexStops: [String],
        angleDegrees: Double = 135,
        textHex: String,
        fontDesign: FontDesign = .standard,
        isFreeForAll: Bool = false
    ) {
        self.id = id
        self.nameKey = nameKey
        self.hexStops = hexStops
        self.angleDegrees = angleDegrees
        self.textHex = textHex
        self.fontDesign = fontDesign
        self.isFreeForAll = isFreeForAll
    }

    /// Every stop must clear 4.5:1 against `textHex`. Enforced by `SelfChecks` and `quotelint`.
    public var worstContrastRatio: Double {
        hexStops.compactMap { ColorMath.contrast(hex: $0, otherHex: textHex) }.min() ?? 0
    }
}

public enum ThemeCatalog {
    /// Order matters: these are shown left-to-right in the theme picker.
    public static let all: [ThemeSpec] = [
        ThemeSpec(
            id: "midnight",
            nameKey: "theme.midnight",
            hexStops: ["#0A1026", "#141C3F", "#1F2B57"],
            textHex: "#F2F4FA",
            fontDesign: .serif,
            isFreeForAll: true
        ),
        ThemeSpec(
            id: "paper",
            nameKey: "theme.paper",
            hexStops: ["#F8F2E7", "#EFE5D3", "#E3D5BC"],
            textHex: "#1E1A14",
            fontDesign: .serif,
            isFreeForAll: true
        ),
        ThemeSpec(
            id: "dusk",
            nameKey: "theme.dusk",
            hexStops: ["#241040", "#3D1A5C", "#552272"],
            textHex: "#F6EFFA",
            fontDesign: .serif
        ),
        ThemeSpec(
            id: "noir",
            nameKey: "theme.noir",
            hexStops: ["#0C0C0E", "#1C1C21", "#2A2A33"],
            textHex: "#F2F2F4",
            fontDesign: .standard
        ),
        ThemeSpec(
            id: "bloom",
            nameKey: "theme.bloom",
            hexStops: ["#FFEFF4", "#FFDDE8", "#FFC9DA"],
            textHex: "#3A1420",
            fontDesign: .rounded
        ),
        ThemeSpec(
            id: "sorbet",
            nameKey: "theme.sorbet",
            hexStops: ["#FFF4E6", "#FFE6CB", "#FFD6AC"],
            textHex: "#3A2410",
            fontDesign: .rounded
        ),
        ThemeSpec(
            id: "static",
            nameKey: "theme.static",
            hexStops: ["#F3F5F8", "#E6EAF0", "#D6DCE6"],
            textHex: "#151A22",
            fontDesign: .standard
        ),
        ThemeSpec(
            id: "mono",
            nameKey: "theme.mono",
            hexStops: ["#FFFFFF", "#F6F6F6", "#ECECEC"],
            textHex: "#141414",
            fontDesign: .standard
        ),
        ThemeSpec(
            id: "forest",
            nameKey: "theme.forest",
            hexStops: ["#06231F", "#0B3A32", "#12544A"],
            textHex: "#EDF7F4",
            fontDesign: .serif
        ),
        ThemeSpec(
            id: "pressed",
            nameKey: "theme.pressed",
            hexStops: ["#15151A", "#24242E", "#333344"],
            textHex: "#F0F0F5",
            fontDesign: .standard
        )
    ]

    public static var free: [ThemeSpec] { all.filter(\.isFreeForAll) }

    public static func theme(id: String) -> ThemeSpec? {
        all.first { $0.id == id }
    }

    public static let `default` = all[0]
}

/// WCAG relative luminance / contrast. Used to prove that every theme is actually readable.
public enum ColorMath {
    public static func components(hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255.0,
            Double((value >> 8) & 0xFF) / 255.0,
            Double(value & 0xFF) / 255.0
        )
    }

    public static func linearize(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    public static func luminance(hex: String) -> Double? {
        guard let c = components(hex: hex) else { return nil }
        return 0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b)
    }

    public static func contrast(hex: String, otherHex: String) -> Double? {
        guard let a = luminance(hex: hex), let b = luminance(hex: otherHex) else { return nil }
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public static func isValidHex(_ hex: String) -> Bool {
        components(hex: hex) != nil
    }
}
