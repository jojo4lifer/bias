import WidgetKit
import SwiftUI
import BiasCore

struct DailyQuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote?
    let groupName: String
    let theme: ThemeSpec
    let language: AppLanguage
}

/// Builds a 10-day timeline in one go.
///
/// WidgetKit's refresh budget is not guaranteed, so nothing here waits for a refresh to show the
/// right quote: every entry is computed up front, at local midnight, from bundled content. If the
/// system never wakes the widget again it will still be correct for ten days.
struct DailyQuoteProvider: TimelineProvider {
    private let repository = QuoteRepository.shared
    private let theme = ThemeCatalog.default
    private let language: AppLanguage = .en

    func placeholder(in context: Context) -> DailyQuoteEntry {
        DailyQuoteEntry(date: Date(), quote: nil, groupName: "", theme: theme, language: language)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyQuoteEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyQuoteEntry>) -> Void) {
        let now = Date()
        guard let groupId = repository.firstGroupId else {
            completion(Timeline(entries: [entry(for: now)], policy: .after(now.addingTimeInterval(3600))))
            return
        }

        let upcoming = repository.store.upcomingQuotes(for: groupId, from: now, dayCount: 10)
        guard !upcoming.isEmpty else {
            completion(Timeline(entries: [entry(for: now)], policy: .after(now.addingTimeInterval(3600))))
            return
        }

        let groupName = repository.store.group(for: groupId)?.name.resolve(language) ?? ""
        let entries = upcoming.map { item in
            DailyQuoteEntry(
                date: item.day,
                quote: item.quote,
                groupName: groupName,
                theme: theme,
                language: language
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> DailyQuoteEntry {
        guard let groupId = repository.firstGroupId else {
            return DailyQuoteEntry(date: date, quote: nil, groupName: "", theme: theme, language: language)
        }
        let quote = repository.store.quote(for: groupId, date: date)
        let groupName = repository.store.group(for: groupId)?.name.resolve(language) ?? ""
        return DailyQuoteEntry(
            date: date,
            quote: quote,
            groupName: groupName,
            theme: theme,
            language: language
        )
    }
}
