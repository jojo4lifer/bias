import WidgetKit
import SwiftUI
import BiasCore

struct DailyQuoteWidget: Widget {
    static let kind = "DailyQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DailyQuoteProvider()) { entry in
            DailyQuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Quote of the day")
        .description("One line from your bias, every morning.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct DailyQuoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyQuoteEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { entry.theme.gradient }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
                .font(.caption2.weight(.medium))
        case .accessoryRectangular:
            rectangular
        case .systemSmall:
            small
        default:
            medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bodyText)
                .font(.system(size: 12, weight: .semibold, design: entry.theme.swiftUIFontDesign))
                .foregroundStyle(entry.theme.textColor)
                .lineLimit(6)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            Text(attribution)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(entry.theme.textColor.opacity(0.75))
                .lineLimit(1)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bodyText)
                .font(.system(size: 15, weight: .semibold, design: entry.theme.swiftUIFontDesign))
                .foregroundStyle(entry.theme.textColor)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline) {
                Text(attribution)
                    .font(.system(size: 10, weight: .medium))
                Spacer(minLength: 8)
                Text(dayLabel)
                    .font(.system(size: 9))
                    .opacity(0.6)
            }
            .foregroundStyle(entry.theme.textColor.opacity(0.8))
            .lineLimit(1)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bodyText)
                .font(.system(size: 11, weight: .medium, design: entry.theme.swiftUIFontDesign))
                .foregroundStyle(entry.theme.textColor)
                .lineLimit(3)
            Text(attribution)
                .font(.system(size: 8))
                .foregroundStyle(entry.theme.textColor.opacity(0.75))
                .lineLimit(1)
        }
    }

    private var familyKind: WidgetFamilyKind {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .accessoryRectangular: return .accessoryRectangular
        case .accessoryInline: return .accessoryInline
        default: return .medium
        }
    }

    private var bodyText: String {
        guard let quote = entry.quote else { return "No quote yet." }
        return familyKind.widgetText(for: quote, language: entry.language)
    }

    private var inlineText: String {
        guard let quote = entry.quote else { return "No quote yet." }
        return "\(quote.memberName.resolve(entry.language)): \(familyKind.widgetText(for: quote, language: entry.language))"
    }

    private var attribution: String {
        guard let quote = entry.quote else { return "" }
        let member = quote.memberName.resolve(entry.language)
        return entry.groupName.isEmpty ? "— \(member)" : "— \(member), \(entry.groupName)"
    }

    private var dayLabel: String {
        entry.date.formatted(.dateTime.month(.abbreviated).day())
    }
}
