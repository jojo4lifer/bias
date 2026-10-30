import Foundation

public enum QuoteRepositoryError: Error, CustomStringConvertible {
    case missingResource

    public var description: String {
        "quotes.json was not found in the bundle"
    }
}

/// Loads the bundled quote database once and hands out a `QuoteStore`.
///
/// Lives in BiasCore so the app and the widget extension share exactly one loading path. Both
/// targets copy `data/quotes.json` into their own bundle, so `Bundle.main` resolves correctly in
/// either process — including inside the widget, where `Bundle.main` is the extension bundle.
public final class QuoteRepository: @unchecked Sendable {
    public static let shared = QuoteRepository()

    public let store: QuoteStore
    /// Non-nil when the bundle is missing or corrupt. The UI must degrade, never crash.
    public let loadError: String?

    public init(bundle: Bundle = .main) {
        do {
            guard let url = bundle.url(forResource: "quotes", withExtension: "json") else {
                throw QuoteRepositoryError.missingResource
            }
            let data = try Data(contentsOf: url)
            store = try QuoteStore(data: data)
            loadError = nil
        } catch {
            store = QuoteStore(database: QuoteDatabase(version: 0, groups: [], quotes: []))
            loadError = String(describing: error)
        }
    }

    public var firstGroupId: String? {
        store.groups.first?.id
    }
}
