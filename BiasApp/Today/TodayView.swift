import SwiftUI
import BiasCore

/// The hero screen: today's quote for the first group the fan follows.
///
/// This is intentionally the smallest thing that proves the pipeline end to end — bundle loads,
/// rotation picks, theme renders. Onboarding, archive, share cards and the paywall come next.
struct TodayView: View {
    private let repository = QuoteRepository.shared
    private let theme = ThemeCatalog.default
    private let language: AppLanguage = .en

    var body: some View {
        ZStack {
            theme.gradient.ignoresSafeArea()
            content
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var content: some View {
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
            quoteCard(quote)
        } else {
            Text("No quote for today yet.")
                .font(.body)
                .foregroundStyle(theme.textColor)
        }
    }

    private func quoteCard(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(quote.text.resolve(language))
                .font(.system(size: 28, weight: .semibold, design: theme.swiftUIFontDesign))
                .foregroundStyle(theme.textColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(attribution(for: quote))
                    .font(.system(size: 14, weight: .medium, design: theme.swiftUIFontDesign))
                Text(quote.source.title)
                    .font(.system(size: 12))
                    .opacity(0.65)
            }
            .foregroundStyle(theme.textColor)
        }
    }

    private func attribution(for quote: Quote) -> String {
        let groupName = repository.store.group(for: quote.groupId)?.name.resolve(language) ?? ""
        let memberName = quote.memberName.resolve(language)
        return groupName.isEmpty ? "— \(memberName)" : "— \(memberName), \(groupName)"
    }

    private var quoteOfTheDay: Quote? {
        guard let groupId = repository.firstGroupId else { return nil }
        return repository.store.quote(for: groupId, date: Date())
    }
}
