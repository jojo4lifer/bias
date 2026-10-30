import WidgetKit
import SwiftUI

struct DailyQuoteWidget: Widget {
    static let kind = "DailyQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DailyQuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Quote of the day")
        .description("One line from your bias, every morning.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        // Content margins off so the shared view's own padding is the only padding. That keeps the
        // in-app preview pixel-honest about what the real widget looks like.
        .contentMarginsDisabled()
    }
}
