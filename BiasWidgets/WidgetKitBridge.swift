import WidgetKit
import SwiftUI
import BiasCore

// The only file that bridges our shared, testable views into WidgetKit. Everything here is a thin
// adapter: a conformance, a case mapping, and one wrapper that adds the background.
//
// Keeping WidgetKit out of `Shared/` is deliberate — it lets the rest of the app be type-checked on
// a Mac with no iOS SDK.

extension QuoteWidgetEntry: TimelineEntry {}

extension WidgetFamily {
    var kind: WidgetFamilyKind {
        switch self {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemLarge: return .medium
        case .systemExtraLarge: return .medium
        case .accessoryRectangular: return .accessoryRectangular
        case .accessoryInline: return .accessoryInline
        case .accessoryCircular: return .accessoryInline
        @unknown default: return .medium
        }
    }
}

/// The real widget: shared content plus the theme background.
struct QuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuoteWidgetEntry

    var body: some View {
        QuoteWidgetContent(entry: entry, family: family.kind)
            .containerBackground(for: .widget) { entry.theme.gradient }
    }
}
