import Foundation

/// Widget families the app supports.
public enum WidgetFamilyKind: String, CaseIterable, Sendable {
    case small
    case medium
    case accessoryRectangular
    case accessoryInline

    /// Lock-screen families have almost no room and need the short variant.
    public var isLockScreen: Bool {
        self == .accessoryRectangular || self == .accessoryInline
    }
}

/// Length budgets, in grapheme clusters.
///
/// Chinese carries roughly twice the meaning per character, hence the halved budgets. These are
/// enforced in `quotelint` so a bad quote fails CI instead of silently truncating on a fan's
/// Home Screen.
public enum QuoteLength {
    public enum Limit {
        public static let quoteEn = 220
        public static let quoteZh = 110
        public static let shortEn = 60
        public static let shortZh = 30
        public static let smallEn = 90
        public static let smallZh = 45
        public static let inlineEn = 25
        public static let inlineZh = 12
    }

    public static func count(_ string: String) -> Int {
        string.count
    }

    public static func limit(for family: WidgetFamilyKind, language: AppLanguage) -> Int {
        let isChinese = language == .zhHans || language == .zhHant
        switch family {
        case .small: return isChinese ? Limit.smallZh : Limit.smallEn
        case .medium: return isChinese ? Limit.quoteZh : Limit.quoteEn
        case .accessoryRectangular: return isChinese ? Limit.shortZh : Limit.shortEn
        case .accessoryInline: return isChinese ? Limit.inlineZh : Limit.inlineEn
        }
    }

    /// Whether a quote can be rendered in a family *at all*, using its best available variant.
    public static func fits(_ quote: Quote, family: WidgetFamilyKind, language: AppLanguage) -> Bool {
        widgetString(for: quote, family: family, language: language) != nil
    }

    /// The string a widget should render, or `nil` if the quote cannot fit that family.
    ///
    /// Preference order is per-family: lock-screen families only ever use `shortText`; Home Screen
    /// families prefer the full quote and fall back to `shortText`.
    public static func widgetString(
        for quote: Quote,
        family: WidgetFamilyKind,
        language: AppLanguage
    ) -> String? {
        let limit = limit(for: family, language: language)
        let full = quote.text.resolve(language)
        let short = quote.shortText?.resolve(language)

        if family.isLockScreen {
            guard let short, short.count <= limit else { return nil }
            return short
        }

        if full.count <= limit { return full }
        if let short, short.count <= limit { return short }
        return nil
    }
}
