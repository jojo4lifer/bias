import SwiftUI


// SwiftUI bridge for the procedural themes.
//
// This lives outside BiasCore on purpose: BiasCore is Foundation-only so it can be compiled and
// tested on a machine with no Xcode. Anything that imports SwiftUI lives here and in the two
// targets that include the `Shared` folder.

extension Color {
    /// Parses `#RRGGBB` or `RRGGBB`. Returns nil rather than a wrong colour.
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((number >> 16) & 0xFF) / 255.0,
            green: Double((number >> 8) & 0xFF) / 255.0,
            blue: Double(number & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

extension ThemeSpec {
    var gradient: LinearGradient {
        let stops = hexStops.compactMap { Color(hex: $0) }
        return LinearGradient(
            colors: stops.isEmpty ? [Color.black, Color.black] : stops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var textColor: Color {
        Color(hex: textHex) ?? .primary
    }

    var swiftUIFontDesign: Font.Design {
        switch fontDesign {
        case .serif: return .serif
        case .rounded: return .rounded
        case .standard: return .default
        }
    }
}

extension WidgetFamilyKind {
    /// The equivalent of a `Quote`, formatted or rejected for this family and language.
    func widgetText(for quote: Quote, language: AppLanguage) -> String {
        QuoteLength.widgetString(for: quote, family: self, language: language)
            ?? quote.shortText?.resolve(language)
            ?? quote.text.resolve(language)
    }
}
