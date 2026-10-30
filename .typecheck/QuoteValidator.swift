import Foundation

public struct ValidationIssue: Hashable, Sendable {
    public enum Severity: String, Hashable, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    public let code: String
    public let message: String
    public let quoteId: String?
    public let groupId: String?

    public init(
        severity: Severity,
        code: String,
        message: String,
        quoteId: String? = nil,
        groupId: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.quoteId = quoteId
        self.groupId = groupId
    }

    public var description: String {
        var parts = ["\(severity.rawValue.uppercased())", code]
        if let groupId { parts.append("group=\(groupId)") }
        if let quoteId { parts.append("quote=\(quoteId)") }
        return parts.joined(separator: " ") + " — " + message
    }
}

/// Enforces the content rules from `docs/content-and-legal.md`.
///
/// Runs both locally (`quotelint`) and in CI, so a quote that breaks a rule cannot reach a fan.
public enum QuoteValidator {
    public enum Mode: String, Sendable {
        /// Work in progress: length and completeness are errors, but short groups and unverified
        /// quotes are only warnings.
        case development
        /// About to ship: everything is an error.
        case shipping
    }

    public struct Options: Sendable {
        public var minimumQuotesPerGroup: Int
        public var requireLaunchLanguages: Bool
        public var forbidSampleQuotes: Bool

        public init(
            minimumQuotesPerGroup: Int = 60,
            requireLaunchLanguages: Bool = true,
            forbidSampleQuotes: Bool = true
        ) {
            self.minimumQuotesPerGroup = minimumQuotesPerGroup
            self.requireLaunchLanguages = requireLaunchLanguages
            self.forbidSampleQuotes = forbidSampleQuotes
        }

        public static let `default` = Options()
        public static let shipping = Options()
        public static let development = Options(minimumQuotesPerGroup: 1, forbidSampleQuotes: false)
    }

    public static func validate(
        _ database: QuoteDatabase,
        mode: Mode = .shipping,
        options: Options = .shipping
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let isShipping = mode == .shipping

        func raise(
            _ code: String,
            _ message: String,
            quoteId: String? = nil,
            groupId: String? = nil,
            shippingOnly: Bool = false,
            devOnlyWarning: Bool = false
        ) {
            let severity: ValidationIssue.Severity
            if shippingOnly {
                severity = isShipping ? .error : .warning
            } else if devOnlyWarning {
                severity = isShipping ? .error : .warning
            } else {
                severity = .error
            }
            issues.append(
                ValidationIssue(
                    severity: severity,
                    code: code,
                    message: message,
                    quoteId: quoteId,
                    groupId: groupId
                )
            )
        }

        let knownGroupIds = Set(database.groups.map(\.id))

        // Groups
        var groupIdCounts: [String: Int] = [:]
        for group in database.groups {
            groupIdCounts[group.id, default: 0] += 1
            if !ColorMath.isValidHex(group.accent) {
                raise(
                    "group.accent",
                    "accent '\(group.accent)' is not a 6-digit hex colour",
                    groupId: group.id
                )
            }
            if options.requireLaunchLanguages, !group.name.isCompleteForLaunch {
                raise(
                    "group.i18n",
                    "group name is missing: "
                        + group.name.missingLaunchLanguages.map(\.rawValue).joined(separator: ", "),
                    groupId: group.id
                )
            }
        }
        for (id, count) in groupIdCounts where count > 1 {
            raise("group.duplicate", "group id declared \(count) times", groupId: id)
        }

        // Quotes
        var seenIds = Set<String>()
        var textByGroup: [String: [String: String]] = [:]   // groupId -> normalized text -> quote id

        for quote in database.quotes {
            if quote.id.isEmpty {
                raise("quote.id", "missing id")
                continue
            }
            if !seenIds.insert(quote.id).inserted {
                raise("quote.duplicateId", "duplicate quote id", quoteId: quote.id)
            }
            if options.forbidSampleQuotes, quote.id.hasPrefix("sample-") {
                raise(
                    "quote.sample",
                    "sample quote present — remove before shipping",
                    quoteId: quote.id
                )
            }
            if !knownGroupIds.contains(quote.groupId) {
                raise(
                    "quote.unknownGroup",
                    "groupId '\(quote.groupId)' is not declared in groups[]",
                    quoteId: quote.id,
                    groupId: quote.groupId
                )
            }

            // Completeness
            if options.requireLaunchLanguages, !quote.text.isCompleteForLaunch {
                raise(
                    "quote.i18n.text",
                    "quote text is missing: "
                        + quote.text.missingLaunchLanguages.map(\.rawValue).joined(separator: ", "),
                    quoteId: quote.id
                )
            }
            if options.requireLaunchLanguages, !quote.memberName.isCompleteForLaunch {
                raise(
                    "quote.i18n.member",
                    "member name is missing: "
                        + quote.memberName.missingLaunchLanguages.map(\.rawValue).joined(separator: ", "),
                    quoteId: quote.id
                )
            }
            if let context = quote.context, !context.isCompleteForLaunch {
                raise("quote.i18n.context", "context is missing a language", quoteId: quote.id)
            }

            // Length
            let en = quote.text.en
            if en.count > QuoteLength.Limit.quoteEn {
                raise(
                    "quote.tooLong.en",
                    "\(en.count) chars exceeds \(QuoteLength.Limit.quoteEn)",
                    quoteId: quote.id
                )
            }
            if let zh = quote.text.zhHans, zh.count > QuoteLength.Limit.quoteZh {
                raise(
                    "quote.tooLong.zh",
                    "\(zh.count) chars exceeds \(QuoteLength.Limit.quoteZh)",
                    quoteId: quote.id
                )
            }

            // Short variant required for lock-screen families
            let needsShort = en.count > QuoteLength.Limit.shortEn
                || (quote.text.zhHans.map { $0.count > QuoteLength.Limit.shortZh } ?? false)
            if needsShort {
                guard let short = quote.shortText else {
                    raise(
                        "quote.missingShort",
                        "text exceeds \(QuoteLength.Limit.shortEn)/\(QuoteLength.Limit.shortZh) chars "
                            + "so shortText is required for lock-screen widgets",
                        quoteId: quote.id
                    )
                    continue
                }
                if short.en.count > QuoteLength.Limit.shortEn {
                    raise(
                        "quote.tooLong.shortEn",
                        "shortText \(short.en.count) chars exceeds \(QuoteLength.Limit.shortEn)",
                        quoteId: quote.id
                    )
                }
                if let zh = short.zhHans, zh.count > QuoteLength.Limit.shortZh {
                    raise(
                        "quote.tooLong.shortZh",
                        "shortText zh \(zh.count) chars exceeds \(QuoteLength.Limit.shortZh)",
                        quoteId: quote.id
                    )
                }
                if options.requireLaunchLanguages, !short.isCompleteForLaunch {
                    raise("quote.i18n.short", "shortText is missing a language", quoteId: quote.id)
                }
            }

            // Sourcing
            if !quote.source.isUsable {
                raise(
                    "quote.source",
                    "source title or ISO date (yyyy-MM-dd) is missing or malformed",
                    quoteId: quote.id
                )
            }
            if quote.source.link == nil {
                raise(
                    "quote.sourceUrl",
                    "no source url — the app promises a link for every quote",
                    quoteId: quote.id,
                    shippingOnly: true
                )
            }

            // Verification
            if !quote.verified {
                raise(
                    "quote.unverified",
                    "verified is not true",
                    quoteId: quote.id,
                    devOnlyWarning: true
                )
            }

            // Duplicate text within a group — the same line attributed to two members
            let normalized = normalize(en)
            if !normalized.isEmpty {
                if let existing = textByGroup[quote.groupId]?[normalized] {
                    raise(
                        "quote.duplicateText",
                        "same text already used by \(existing)",
                        quoteId: quote.id,
                        groupId: quote.groupId
                    )
                } else {
                    textByGroup[quote.groupId, default: [:]][normalized] = quote.id
                }
            }

            if quote.id.range(of: "^[a-z0-9]+-[a-z0-9]+-\\d{4}$", options: .regularExpression) == nil {
                raise(
                    "quote.idFormat",
                    "id should look like <group>-<member>-<0001>",
                    quoteId: quote.id,
                    devOnlyWarning: true
                )
            }
        }

        // Content gate per group
        var activeCounts: [String: Int] = [:]
        for quote in database.quotes where !quote.retired {
            activeCounts[quote.groupId, default: 0] += 1
        }
        for group in database.groups {
            let count = activeCounts[group.id] ?? 0
            if count == 0 {
                raise("group.empty", "group has no active quotes", groupId: group.id, devOnlyWarning: true)
            } else if count < options.minimumQuotesPerGroup {
                raise(
                    "group.thin",
                    "\(count) active quotes, minimum is \(options.minimumQuotesPerGroup) — "
                        + "fans will see repeats too soon",
                    groupId: group.id,
                    devOnlyWarning: true
                )
            }
        }

        return issues
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
