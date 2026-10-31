import SwiftUI
import BiasCore

/// The hero screen: today's quote for the first group the fan follows.
///
/// Layout intent: a masthead, a vertically centred quote, and a footer. Centring the quote is what
/// stops a short line from leaving a hole in the middle of the screen — the version that pinned the
/// quote to the top and the credit to the bottom looked unfinished rather than minimal.
struct TodayView: View {
    private let repository = QuoteRepository.shared
    private let theme = ThemeCatalog.default
    private let language: AppLanguage = .en

    var body: some View {
        ZStack {
            theme.gradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 20)

                main

                Spacer(minLength: 20)

                footer
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .tracking(2.4)
            Spacer(minLength: 12)
            Text(dateLabel)
                .font(.caption)
        }
        .foregroundStyle(theme.textColor.opacity(0.55))
    }

    @ViewBuilder
    private var main: some View {
        if let loadError = repository.loadError {
            VStack(alignment: .leading, spacing: 10) {
                Text("Content is missing")
                    .font(.title2.weight(.semibold))
                Text(loadError)
                    .font(.footnote.monospaced())
                    .opacity(0.8)
            }
            .foregroundStyle(theme.textColor)
        } else if let quote = quoteOfTheDay {
            Text(quote.text.resolve(language))
                .font(.system(size: 32, weight: .semibold, design: theme.swiftUIFontDesign))
                .foregroundStyle(theme.textColor)
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("No quote for today yet.")
                .font(.body)
                .foregroundStyle(theme.textColor)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let quote = quoteOfTheDay {
            VStack(alignment: .leading, spacing: 5) {
                Text(attribution(for: quote))
                    .font(.system(size: 15, weight: .medium, design: theme.swiftUIFontDesign))
                Text(quote.source.title)
                    .font(.system(size: 12))
                    .opacity(0.6)
            }
            .foregroundStyle(theme.textColor)
        }
    }

    // MARK: - Data

    private func attribution(for quote: Quote) -> String {
        let groupName = repository.store.group(for: quote.groupId)?.name.resolve(language) ?? ""
        let memberName = quote.memberName.resolve(language)
        return groupName.isEmpty ? "— \(memberName)" : "— \(memberName), \(groupName)"
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.month(.wide).day())
    }

    private var quoteOfTheDay: Quote? {
        guard let groupId = repository.firstGroupId else { return nil }
        return repository.store.quote(for: groupId, date: Date())
    }
}
