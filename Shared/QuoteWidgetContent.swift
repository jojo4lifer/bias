import SwiftUI
import BiasCore

/// The widget's content, independent of WidgetKit.
///
/// No `import WidgetKit` on purpose: this is the part that decides what a fan actually reads, so it
/// must be verifiable without an iOS SDK. `QuoteWidgetView` in the widget target wraps it.
///
/// The widget disables system content margins (`contentMarginsDisabled()`), so the padding here is
/// the only padding — which keeps the in-app preview pixel-honest.
struct QuoteWidgetContent: View {
    let entry: QuoteWidgetEntry
    let family: WidgetFamilyKind

    var body: some View {
        Group {
            switch family {
            case .small:
                small
            case .medium:
                medium
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                inline
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var padding: CGFloat {
        switch family {
        case .small: return 12
        case .medium: return 16
        case .accessoryRectangular: return 6
        case .accessoryInline: return 0
        }
    }

    // MARK: - Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(bodyText)
                .font(.system(size: 12, weight: .semibold, design: entry.theme.swiftUIFontDesign))
                .foregroundStyle(entry.theme.textColor)
                .lineLimit(6)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text(attribution)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(entry.theme.textColor.opacity(0.75))
                .lineLimit(1)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(bodyText)
                .font(.system(size: 15, weight: .semibold, design: entry.theme.swiftUIFontDesign))
                .foregroundStyle(entry.theme.textColor)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(attribution)
                    .font(.system(size: 10, weight: .medium))
                Spacer(minLength: 0)
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
            Spacer(minLength: 0)
            Text(bodyText)
                .font(.system(size: 11, weight: .medium, design: entry.theme.swiftUIFontDesign))
                .foregroundStyle(entry.theme.textColor)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text(attribution)
                .font(.system(size: 8))
                .foregroundStyle(entry.theme.textColor.opacity(0.75))
                .lineLimit(1)
        }
    }

    private var inline: some View {
        Text(inlineText)
            .font(.caption2.weight(.medium))
            .foregroundStyle(entry.theme.textColor)
            .lineLimit(1)
    }

    // MARK: - Text

    private var bodyText: String {
        guard let quote = entry.quote else { return "No quote yet." }
        return family.widgetText(for: quote, language: entry.language)
    }

    private var inlineText: String {
        guard let quote = entry.quote else { return "No quote yet." }
        let member = quote.memberName.resolve(entry.language)
        return "\(member): \(family.widgetText(for: quote, language: entry.language))"
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
