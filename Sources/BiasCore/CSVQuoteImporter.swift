import Foundation

public struct ImportIssue: Hashable, Sendable {
    public enum Severity: String, Hashable, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    /// 1-based line in the source CSV.
    public let line: Int?
    public let message: String

    public init(severity: Severity, line: Int? = nil, message: String) {
        self.severity = severity
        self.line = line
        self.message = message
    }

    public var description: String {
        let location = line.map { "line \($0): " } ?? ""
        return "\(severity.rawValue.uppercased()) \(location)\(message)"
    }
}

public struct ImportResult: Sendable {
    public let database: QuoteDatabase
    public let issues: [ImportIssue]

    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }
}

/// Turns two human-edited spreadsheets into `quotes.json`.
///
/// The CSV is the source of truth because a curator lives in a spreadsheet. JSON is a build
/// artefact, and is generated with sorted keys so diffs stay readable in git.
public enum QuoteCSVImporter {
    // MARK: - Schema

    public static let groupsHeader = [
        "id", "name_en", "name_zh", "name_zh_hant", "debut", "accent"
    ]

    public static let quotesHeader = [
        "id",
        "group_id",
        "member_id",
        "member_en",
        "member_zh",
        "member_zh_hant",
        "text_en",
        "text_zh",
        "text_zh_hant",
        "short_en",
        "short_zh",
        "short_zh_hant",
        "context_en",
        "context_zh",
        "context_zh_hant",
        "source_title",
        "source_date",
        "source_url",
        "lang",
        "tags",
        "verified",
        "retired",
        "notes"
    ]

    private static let requiredGroupColumns = ["id", "name_en"]
    private static let requiredQuoteColumns = [
        "id", "group_id", "member_id", "text_en", "source_title", "source_date"
    ]

    private static let trueTokens: Set<String> = [
        "true", "t", "yes", "y", "1", "checked", "done", "是", "对", "✓", "√"
    ]
    private static let falseTokens: Set<String> = [
        "false", "f", "no", "n", "0", "否", "不是", ""
    ]

    private static let defaultAccent = "#7B5CFA"

    // MARK: - Build

    public static func build(
        groupsCSV: String,
        quotesCSV: String,
        version: Int = 1,
        generatedAt: String = ""
    ) -> ImportResult {
        var issues: [ImportIssue] = []

        func error(_ message: String, line: Int? = nil) {
            issues.append(ImportIssue(severity: .error, line: line, message: message))
        }
        func warn(_ message: String, line: Int? = nil) {
            issues.append(ImportIssue(severity: .warning, line: line, message: message))
        }

        // MARK: Groups

        let groupsTable = CSV.parse(groupsCSV)
        for column in requiredGroupColumns where !groupsTable.has(column) {
            error("groups file is missing the '\(column)' column")
        }

        var groups: [QuoteGroup] = []
        var seenGroupIds = Set<String>()

        for (offset, row) in groupsTable.rows.enumerated() {
            let line = groupsTable.lineNumbers[offset]
            guard let id = groupsTable.value("id", in: row) else {
                error("group row has no id", line: line)
                continue
            }
            if !seenGroupIds.insert(id).inserted {
                error("duplicate group id '\(id)'", line: line)
                continue
            }
            guard let nameEn = groupsTable.value("name_en", in: row) else {
                error("group '\(id)' has no name_en", line: line)
                continue
            }
            var accent = groupsTable.value("accent", in: row) ?? defaultAccent
            if !accent.hasPrefix("#") { accent = "#" + accent }
            if !ColorMath.isValidHex(accent) {
                warn("group '\(id)' has an invalid accent '\(accent)', using \(defaultAccent)", line: line)
                accent = defaultAccent
            }
            let debut = groupsTable.value("debut", in: row).flatMap(Int.init)
            groups.append(
                QuoteGroup(
                    id: id,
                    name: LocalizedText(
                        en: nameEn,
                        zhHans: groupsTable.value("name_zh", in: row),
                        zhHant: groupsTable.value("name_zh_hant", in: row)
                    ),
                    debut: debut,
                    accent: accent
                )
            )
        }

        // MARK: Quotes

        let quotesTable = CSV.parse(quotesCSV)
        for column in requiredQuoteColumns where !quotesTable.has(column) {
            error("quotes file is missing the '\(column)' column")
        }

        let knownGroupIds = Set(groups.map(\.id))
        var quotes: [Quote] = []
        var seenQuoteIds = [String: Int]()

        for (offset, row) in quotesTable.rows.enumerated() {
            let line = quotesTable.lineNumbers[offset]

            // Skip rows the curator has only partially filled in (e.g. a trailing blank row).
            let rawValues = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if rawValues.allSatisfy({ $0.isEmpty }) { continue }

            guard let id = quotesTable.value("id", in: row) else {
                error("quote has no id", line: line)
                continue
            }
            if let previousLine = seenQuoteIds[id] {
                error("duplicate quote id '\(id)' (already used on line \(previousLine))", line: line)
                continue
            }
            seenQuoteIds[id] = line

            guard let groupId = quotesTable.value("group_id", in: row) else {
                error("quote '\(id)' has no group_id", line: line)
                continue
            }
            if !knownGroupIds.contains(groupId) {
                error("quote '\(id)' refers to unknown group '\(groupId)'", line: line)
                continue
            }
            guard let memberId = quotesTable.value("member_id", in: row) else {
                error("quote '\(id)' has no member_id", line: line)
                continue
            }
            guard let textEn = quotesTable.value("text_en", in: row) else {
                error("quote '\(id)' has no text_en", line: line)
                continue
            }
            guard let sourceTitle = quotesTable.value("source_title", in: row) else {
                error("quote '\(id)' has no source_title", line: line)
                continue
            }
            guard let rawDate = quotesTable.value("source_date", in: row) else {
                error("quote '\(id)' has no source_date", line: line)
                continue
            }
            guard let sourceDate = normalizeDate(rawDate) else {
                error(
                    "quote '\(id)' has source_date '\(rawDate)' — use yyyy-mm-dd "
                        + "(format the cell as plain text, not a locale date)",
                    line: line
                )
                continue
            }

            let memberName = LocalizedText(
                en: quotesTable.value("member_en", in: row) ?? memberId,
                zhHans: quotesTable.value("member_zh", in: row),
                zhHant: quotesTable.value("member_zh_hant", in: row)
            )
            if quotesTable.value("member_en", in: row) == nil {
                warn("quote '\(id)' has no member_en, falling back to member_id", line: line)
            }

            let text = LocalizedText(
                en: textEn,
                zhHans: quotesTable.value("text_zh", in: row),
                zhHant: quotesTable.value("text_zh_hant", in: row)
            )

            var shortText: LocalizedText?
            if quotesTable.has("short_en") || quotesTable.has("short_zh") {
                let en = quotesTable.value("short_en", in: row)
                let zh = quotesTable.value("short_zh", in: row)
                let hant = quotesTable.value("short_zh_hant", in: row)
                if en != nil || zh != nil {
                    shortText = LocalizedText(en: en ?? zh ?? "", zhHans: zh, zhHant: hant)
                }
            }

            var context: LocalizedText?
            if let en = quotesTable.value("context_en", in: row) {
                context = LocalizedText(
                    en: en,
                    zhHans: quotesTable.value("context_zh", in: row),
                    zhHant: quotesTable.value("context_zh_hant", in: row)
                )
            }

            var verified = false
            if let raw = quotesTable.value("verified", in: row)?.lowercased() {
                if trueTokens.contains(raw) {
                    verified = true
                } else if falseTokens.contains(raw) {
                    verified = false
                } else {
                    warn("quote '\(id)' has unrecognised verified value '\(raw)', treated as false", line: line)
                }
            }

            var retired = false
            if let raw = quotesTable.value("retired", in: row)?.lowercased() {
                retired = trueTokens.contains(raw)
            }

            quotes.append(
                Quote(
                    id: id,
                    groupId: groupId,
                    memberId: memberId,
                    memberName: memberName,
                    text: text,
                    shortText: shortText,
                    context: context,
                    source: QuoteSource(
                        title: sourceTitle,
                        date: sourceDate,
                        url: quotesTable.value("source_url", in: row)
                    ),
                    lang: quotesTable.value("lang", in: row)?.lowercased() ?? "ko",
                    tags: parseTags(quotesTable.value("tags", in: row)),
                    verified: verified,
                    retired: retired
                )
            )
        }

        let database = QuoteDatabase(
            version: version,
            generatedAt: generatedAt.isEmpty ? nil : generatedAt,
            groups: groups,
            quotes: quotes
        )
        return ImportResult(database: database, issues: issues)
    }

    // MARK: - Helpers

    static func parseTags(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        let separators = CharacterSet(charactersIn: ";,、|/")
        return raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// Accepts the shapes a spreadsheet actually produces. Everything else is rejected rather than
    /// guessed at, because a wrong date on a quote is a credibility problem.
    static func normalizeDate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if QuoteSource.isISODate(trimmed) { return trimmed }

        let parts = trimmed.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" })
            .map(String.init)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1900...2100).contains(year),
              (1...12).contains(month),
              (1...31).contains(day)
        else {
            if trimmed.count == 8, let compact = Int(trimmed) {
                let y = compact / 10_000
                let m = (compact / 100) % 100
                let d = compact % 100
                if (1900...2100).contains(y), (1...12).contains(m), (1...31).contains(d) {
                    return String(format: "%04d-%02d-%02d", y, m, d)
                }
            }
            return nil
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Templates

    public static func templateGroupsCSV() -> String {
        CSV.encode(
            header: groupsHeader,
            rows: [
                ["group-a", "Group A", "组合甲", "組合甲", "2013", "#7B5CFA"]
            ]
        )
    }

    public static func templateQuotesCSV() -> String {
        CSV.encode(
            header: quotesHeader,
            rows: [
                [
                    "sample-group-a-m1-0001",
                    "group-a",
                    "m1",
                    "Member One",
                    "成员一",
                    "",
                    "PLACEHOLDER — a fake quote used to show the shape of a row. Delete this row.",
                    "占位文字 — 用来展示一行的格式，请删除。",
                    "",
                    "PLACEHOLDER — short version.",
                    "占位短句。",
                    "",
                    "Said during a livestream.",
                    "在直播中提到。",
                    "",
                    "Weverse Live",
                    "2021-05-21",
                    "https://example.com/placeholder",
                    "ko",
                    "comfort; nostalgia",
                    "TRUE",
                    "FALSE",
                    "delete me"
                ]
            ]
        )
    }
}

// MARK: - Encoding

public extension QuoteDatabase {
    /// Stable, diff-friendly JSON. Sorted keys mean a one-quote change shows up as a one-quote diff.
    func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
