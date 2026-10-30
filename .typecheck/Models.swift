import Foundation

/// A group a fan can follow. Names are localized; `accent` is a hex colour used to theme the
/// widget when the fan has not chosen a theme.
public struct QuoteGroup: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: LocalizedText
    public let debut: Int?
    public let accent: String

    public init(id: String, name: LocalizedText, debut: Int? = nil, accent: String) {
        self.id = id
        self.name = name
        self.debut = debut
        self.accent = accent
    }
}

/// Where a quote came from. This is not decoration: it is the legal backbone of the product.
public struct QuoteSource: Codable, Hashable, Sendable {
    public let title: String
    /// `yyyy-MM-dd`. Kept as a string so the JSON stays human-editable and diff-friendly.
    public let date: String
    public let url: String?

    public init(title: String, date: String, url: String? = nil) {
        self.title = title
        self.date = date
        self.url = url
    }

    public var link: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    /// A source is only usable if it names the outlet and dates the statement.
    public var isUsable: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Self.isISODate(date)
    }

    public static func isISODate(_ value: String) -> Bool {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              year >= 1990, (1...12).contains(month), (1...31).contains(day)
        else { return false }
        return true
    }
}

/// One idol quote.
public struct Quote: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let groupId: String
    public let memberId: String
    public let memberName: LocalizedText
    public let text: LocalizedText
    /// Required when `text` is too long for a lock-screen widget. See `QuoteLength`.
    public let shortText: LocalizedText?
    /// The human context, e.g. "Said during a Weverse livestream."
    public let context: LocalizedText?
    public let source: QuoteSource
    /// Original language of the quote (ISO-ish code: ko, en, ja, zh).
    public let lang: String
    public let tags: [String]
    /// Only `true` quotes may ship. Defaults to `false` so an omission fails the linter.
    public let verified: Bool
    /// Soft-delete. Retired quotes stay in the file so history and diffs stay intact.
    public let retired: Bool

    public init(
        id: String,
        groupId: String,
        memberId: String,
        memberName: LocalizedText,
        text: LocalizedText,
        shortText: LocalizedText? = nil,
        context: LocalizedText? = nil,
        source: QuoteSource,
        lang: String,
        tags: [String] = [],
        verified: Bool = false,
        retired: Bool = false
    ) {
        self.id = id
        self.groupId = groupId
        self.memberId = memberId
        self.memberName = memberName
        self.text = text
        self.shortText = shortText
        self.context = context
        self.source = source
        self.lang = lang
        self.tags = tags
        self.verified = verified
        self.retired = retired
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        groupId = try c.decode(String.self, forKey: .groupId)
        memberId = try c.decode(String.self, forKey: .memberId)
        memberName = try c.decode(LocalizedText.self, forKey: .memberName)
        text = try c.decode(LocalizedText.self, forKey: .text)
        shortText = try c.decodeIfPresent(LocalizedText.self, forKey: .shortText)
        context = try c.decodeIfPresent(LocalizedText.self, forKey: .context)
        source = try c.decode(QuoteSource.self, forKey: .source)
        lang = try c.decodeIfPresent(String.self, forKey: .lang) ?? "ko"
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        verified = try c.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        retired = try c.decodeIfPresent(Bool.self, forKey: .retired) ?? false
    }
}

/// The whole bundled content file.
public struct QuoteDatabase: Codable, Sendable {
    public let version: Int
    public let generatedAt: String?
    public let groups: [QuoteGroup]
    public let quotes: [Quote]

    public init(
        version: Int,
        generatedAt: String? = nil,
        groups: [QuoteGroup],
        quotes: [Quote]
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.groups = groups
        self.quotes = quotes
    }
}
