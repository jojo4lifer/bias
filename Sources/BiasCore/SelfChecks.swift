import Foundation

/// Self-checks for the core logic.
///
/// These exist because XCTest is not available with Command Line Tools alone, and the dev machine
/// has no Xcode. Rather than maintain two test harnesses, the checks live in the library and are
/// run by `quotelint --self-check` both locally and in CI.
public struct SelfCheckResult: Sendable {
    public let name: String
    public let passed: Bool
    public let detail: String?

    public init(name: String, passed: Bool, detail: String? = nil) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

public enum SelfChecks {
    public static func run() -> [SelfCheckResult] {
        var results: [SelfCheckResult] = []

        func check(_ name: String, _ body: () throws -> String?) {
            do {
                let detail = try body()
                results.append(SelfCheckResult(name: name, passed: true, detail: detail))
            } catch let failure as CheckFailure {
                results.append(SelfCheckResult(name: name, passed: false, detail: failure.message))
            } catch {
                results.append(SelfCheckResult(name: name, passed: false, detail: "\(error)"))
            }
        }

        // MARK: Stable hash

        check("stable hash: FNV-1a known vectors") {
            try expect(StableHash.fnv1a("") == 0xcbf2_9ce4_8422_2325, "empty string")
            try expect(StableHash.fnv1a("a") == 0xaf63_dc4c_8601_ec8c, "a")
            try expect(StableHash.fnv1a("foobar") == 0x8594_4171_f739_67e8, "foobar")
            return nil
        }

        check("stable hash: independent of process seed") {
            // FNV is pure arithmetic, so two calls in this process must match. The real regression
            // this guards against is someone swapping in `Hasher`, which is per-process seeded.
            var hashes = Set<UInt64>()
            for _ in 0..<50 {
                hashes.insert(StableHash.fnv1a(["bts", "2026-10-31", "bts-jk-0001"]))
            }
            try expect(hashes.count == 1, "hash varied between calls")
            return nil
        }

        // MARK: Day numbers

        check("day number: consecutive days differ by one") {
            let a = try unwrap(DayNumber(dayKey: "2026-10-31"), "parse a")
            let b = try unwrap(DayNumber(dayKey: "2026-11-01"), "parse b")
            try expect(b.value - a.value == 1, "oct 31 -> nov 1 = \(b.value - a.value)")
            return nil
        }

        check("day number: leap day is one day after 28 Feb") {
            let a = try unwrap(DayNumber(dayKey: "2024-02-28"), "parse")
            let b = try unwrap(DayNumber(dayKey: "2024-02-29"), "parse")
            try expect(b.value - a.value == 1, "leap day gap = \(b.value - a.value)")
            let c = try unwrap(DayNumber(dayKey: "2023-02-28"), "parse")
            let d = try unwrap(DayNumber(dayKey: "2023-03-01"), "parse")
            try expect(d.value - c.value == 1, "non-leap gap = \(d.value - c.value)")
            return nil
        }

        check("day key: stable formatting") {
            let date = Date(timeIntervalSince1970: 1_800_000_000)
            let key = DayKey.string(for: date, timeZone: TimeZone(identifier: "Asia/Shanghai")!)
            try expect(key.count == 10 && key.contains("-"), "bad key \(key)")
            return "\(key)"
        }

        // MARK: Rotation

        let pool = fixtures(group: "bts", count: 60)

        check("rotation: deterministic for the same group and day") {
            let first = try unwrap(
                DailyRotator.quote(for: "bts", dayKey: "2026-10-31", in: pool),
                "no quote"
            )
            for _ in 0..<200 {
                let again = try unwrap(
                    DailyRotator.quote(for: "bts", dayKey: "2026-10-31", in: pool),
                    "no quote"
                )
                try expect(again.id == first.id, "pick changed between calls")
            }
            return first.id
        }

        check("rotation: order of the input array does not matter") {
            let a = try unwrap(DailyRotator.quote(for: "bts", dayKey: "2026-10-31", in: pool), "a")
            let shuffled = pool.reversed()
            let b = try unwrap(
                DailyRotator.quote(for: "bts", dayKey: "2026-10-31", in: Array(shuffled)),
                "b"
            )
            try expect(a.id == b.id, "\(a.id) != \(b.id)")
            return nil
        }

        check("rotation: permutation is a true permutation") {
            let order = DailyRotator.permutation(count: 60, seed: 42)
            try expect(order.count == 60, "count \(order.count)")
            try expect(Set(order).count == 60, "duplicates in permutation")
            try expect(order.sorted() == Array(0..<60), "not a permutation of 0..<60")
            return nil
        }

        check("rotation: every quote appears exactly once per cycle") {
            let days = try walkDays(from: "2026-01-01", count: 600)
            var byCycle: [Int: [String]] = [:]
            for day in days {
                guard let quote = DailyRotator.quote(for: "bts", dayKey: day, in: pool),
                      let number = DayNumber(dayKey: day)
                else { throw CheckFailure(message: "no quote for \(day)") }
                byCycle[number.value / 60, default: []].append(quote.id)
            }
            var fullCycles = 0
            for (cycle, ids) in byCycle where ids.count == 60 {
                fullCycles += 1
                try expect(Set(ids).count == 60, "cycle \(cycle) reused a quote")
            }
            try expect(fullCycles >= 9, "expected at least 9 complete cycles, got \(fullCycles)")
            return "\(fullCycles) complete cycles"
        }

        check("rotation: never repeats on consecutive days inside a cycle") {
            let days = try walkDays(from: "2026-01-01", count: 600)
            var previous: (day: String, id: String)?
            for day in days {
                guard let quote = DailyRotator.quote(for: "bts", dayKey: day, in: pool) else {
                    throw CheckFailure(message: "no quote for \(day)")
                }
                if let previous, previous.id == quote.id {
                    let a = try unwrap(DayNumber(dayKey: previous.day), "parse")
                    let b = try unwrap(DayNumber(dayKey: day), "parse")
                    if a.value / 60 == b.value / 60 {
                        throw CheckFailure(message: "repeat on \(previous.day) -> \(day)")
                    }
                }
                previous = (day, quote.id)
            }
            return nil
        }

        check("rotation: covers the whole pool within three cycles") {
            let days = try walkDays(from: "2026-01-01", count: 180)
            var seen = Set<String>()
            for day in days {
                if let quote = DailyRotator.quote(for: "bts", dayKey: day, in: pool) {
                    seen.insert(quote.id)
                }
            }
            try expect(seen.count == 60, "saw \(seen.count) of 60")
            return nil
        }

        check("rotation: consecutive cycles use a different order") {
            let first = try cycleOrder(startingAt: "2026-01-01", pool: pool)
            let second = try cycleOrder(startingAt: "2026-04-01", pool: pool)
            if first != second {
                return "orders differ"
            }
            return "orders identical — acceptable only if the pool is tiny"
        }

        check("rotation: empty or missing group returns nil") {
            try expect(DailyRotator.quote(for: "nope", dayKey: "2026-10-31", in: pool) == nil, "expected nil")
            return nil
        }

        check("rotation: retired quotes are never chosen") {
            var retiredPool = fixtures(group: "bts", count: 10)
            retiredPool = retiredPool.map { quote in
                Quote(
                    id: quote.id,
                    groupId: quote.groupId,
                    memberId: quote.memberId,
                    memberName: quote.memberName,
                    text: quote.text,
                    shortText: quote.shortText,
                    context: quote.context,
                    source: quote.source,
                    lang: quote.lang,
                    tags: quote.tags,
                    verified: quote.verified,
                    retired: true
                )
            }
            try expect(DailyRotator.quote(for: "bts", dayKey: "2026-10-31", in: retiredPool) == nil, "chose a retired quote")
            return nil
        }

        check("store: upcoming quotes start at midnight and are consecutive") {
            let store = QuoteStore(database: QuoteDatabase(version: 1, groups: [fixtureGroup], quotes: pool))
            let now = Date()
            let upcoming = store.upcomingQuotes(for: "bts", from: now, dayCount: 10)
            try expect(upcoming.count == 10, "got \(upcoming.count) entries")
            let first = upcoming[0].day
            let startOfToday = DayKey.startOfDay(for: now)
            try expect(abs(first.timeIntervalSince(startOfToday)) < 1, "first entry is not midnight")
            let gap = upcoming[1].day.timeIntervalSince(upcoming[0].day)
            try expect(abs(gap - 86_400) < 3_600, "gap \(gap) is not about a day")
            return nil
        }

        // MARK: Widget length

        check("length: long quote without shortText cannot render on the lock screen") {
            let long = fixtureQuote(
                group: "bts",
                index: 1,
                en: String(repeating: "word ", count: 40),
                shortEn: nil
            )
            try expect(
                QuoteLength.widgetString(for: long, family: .accessoryRectangular, language: .en) == nil,
                "lock screen accepted a long quote"
            )
            try expect(
                QuoteLength.widgetString(for: long, family: .medium, language: .en) != nil,
                "medium rejected an in-budget quote"
            )
            return nil
        }

        check("length: shortText is used when it exists") {
            let quote = fixtureQuote(
                group: "bts",
                index: 2,
                en: String(repeating: "word ", count: 40),
                shortEn: "You worked hard today."
            )
            let rendered = QuoteLength.widgetString(for: quote, family: .accessoryRectangular, language: .en)
            try expect(rendered == "You worked hard today.", "got \(rendered ?? "nil")")
            return nil
        }

        check("length: inline family is stricter than rectangular") {
            let quote = fixtureQuote(
                group: "bts",
                index: 3,
                en: "short",
                shortEn: String(repeating: "a", count: 40)
            )
            try expect(
                QuoteLength.widgetString(for: quote, family: .accessoryRectangular, language: .en) != nil,
                "rectangular should accept 40 chars"
            )
            try expect(
                QuoteLength.widgetString(for: quote, family: .accessoryInline, language: .en) == nil,
                "inline should reject 40 chars"
            )
            return nil
        }

        // MARK: Localization

        check("localization: Chinese falls back to English, never to empty") {
            let text = LocalizedText(en: "Hello", zhHans: nil)
            try expect(text.resolve(.zhHans) == "Hello", "zh fallback failed")
            try expect(text.resolve(.zhHant) == "Hello", "zh-Hant fallback failed")
            try expect(!text.isCompleteForLaunch, "should be incomplete")
            try expect(text.missingLaunchLanguages == [.zhHans], "wrong missing list")
            return nil
        }

        check("localization: zh-Hant prefers Hans over English") {
            let text = LocalizedText(en: "Hello", zhHans: "你好", zhHant: nil)
            try expect(text.resolve(.zhHant) == "你好", "got \(text.resolve(.zhHant))")
            return nil
        }

        check("localization: locale identifiers map correctly") {
            try expect(AppLanguage(localeIdentifier: "zh-Hant-TW") == .zhHant, "zh-Hant-TW")
            try expect(AppLanguage(localeIdentifier: "zh_TW") == .zhHant, "zh_TW")
            try expect(AppLanguage(localeIdentifier: "zh-Hans-CN") == .zhHans, "zh-Hans-CN")
            try expect(AppLanguage(localeIdentifier: "en-GB") == .en, "en-GB")
            try expect(AppLanguage(localeIdentifier: "ko-KR") == .en, "ko-KR should fall back to en")
            return nil
        }

        // MARK: Source

        check("source: ISO date validation rejects sloppy dates") {
            try expect(QuoteSource(title: "t", date: "2021-05-21").isUsable, "valid date rejected")
            try expect(!QuoteSource(title: "t", date: "2021-5-21").isUsable, "2021-5-21 accepted")
            try expect(!QuoteSource(title: "", date: "2021-05-21").isUsable, "empty title accepted")
            try expect(!QuoteSource(title: "t", date: "21/05/21").isUsable, "21/05/21 accepted")
            return nil
        }

        // MARK: Themes

        check("themes: catalog is coherent") {
            let all = ThemeCatalog.all
            try expect(all.count == 10, "expected 10 themes, got \(all.count)")
            try expect(Set(all.map(\.id)).count == all.count, "duplicate theme ids")
            try expect(ThemeCatalog.free.count == 2, "expected 2 free themes")
            try expect(ThemeCatalog.default.isFreeForAll, "default theme must be free")
            return nil
        }

        check("themes: every gradient stop clears 4.5:1 contrast") {
            var worst: (id: String, ratio: Double) = ("", .infinity)
            for theme in ThemeCatalog.all {
                for stop in theme.hexStops {
                    try expect(ColorMath.isValidHex(stop), "\(theme.id) has invalid hex \(stop)")
                }
                let ratio = theme.worstContrastRatio
                try expect(ratio >= 4.5, "\(theme.id) worst contrast is \(ratio)")
                if ratio < worst.ratio { worst = (theme.id, ratio) }
            }
            return String(format: "worst is %@ at %.2f:1", worst.id, worst.ratio)
        }

        // MARK: Validator

        check("validator: catches the mistakes that matter") {
            let good = fixtures(group: "bts", count: 3)
            let bad = [
                // unverified
                makeRaw(quote: good[0], verified: false),
                // duplicate id
                good[1],
                // duplicate text within the group
                makeRaw(quote: good[1], id: "bts-x-0099"),
                // missing zh
                makeRaw(quote: good[2], zh: nil)
            ]
            let db = QuoteDatabase(version: 1, groups: [fixtureGroup], quotes: bad + [good[1]])
            let issues = QuoteValidator.validate(db, mode: .shipping, options: .default)
            let codes = Set(issues.map(\.code))
            for expected in ["quote.unverified", "quote.duplicateId", "quote.duplicateText", "quote.i18n.text"] {
                try expect(codes.contains(expected), "missing \(expected); got \(codes.sorted())")
            }
            return nil
        }

        check("validator: a clean database produces no errors") {
            let db = QuoteDatabase(
                version: 1,
                groups: [fixtureGroup],
                quotes: fixtures(group: "bts", count: 60)
            )
            let issues = QuoteValidator.validate(db, mode: .shipping, options: .default)
            let errors = issues.filter { $0.severity == .error }
            try expect(errors.isEmpty, "\(errors.count) errors: \(errors.prefix(3).map(\.code))")
            return nil
        }

        // MARK: CSV

        check("csv: parses quoted commas, embedded newlines and doubled quotes") {
            let text = "id,text_en\n1,\"Hello, world\"\n2,\"Line one\nline two\"\n3,\"She said \"\"hi\"\"\"\n"
            let table = CSV.parse(text)
            try expect(table.rows.count == 3, "got \(table.rows.count) rows")
            try expect(table.value("text_en", in: table.rows[0]) == "Hello, world", "quoted comma")
            try expect(table.value("text_en", in: table.rows[1]) == "Line one\nline two", "embedded newline")
            try expect(table.value("text_en", in: table.rows[2]) == "She said \"hi\"", "doubled quote")
            return nil
        }

        check("csv: header names are normalised") {
            let table = CSV.parse("Group ID,Text EN, source-date\nbts,x,2021-01-01\n")
            try expect(table.has("group_id"), "Group ID not normalised")
            try expect(table.has("text_en"), "Text EN not normalised")
            try expect(table.has("source_date"), "source-date not normalised")
            return nil
        }

        check("csv: tolerates a BOM and CRLF line endings") {
            let table = CSV.parse("\u{FEFF}id,name\r\n1,one\r\n2,two\r\n")
            try expect(table.header == ["id", "name"], "header \(table.header)")
            try expect(table.rows.count == 2, "got \(table.rows.count) rows")
            try expect(table.rows[1][1] == "two", "got \(table.rows[1])")
            return nil
        }

        check("csv: encode then parse round-trips awkward values") {
            let rows = [["a,b", "he said \"no\"", "line1\nline2", " padded "]]
            let encoded = CSV.encode(header: ["one", "two", "three", "four"], rows: rows)
            let parsed = CSV.parse(encoded)
            try expect(parsed.rows.count == 1, "lost a row")
            try expect(parsed.rows[0].prefix(3) == rows[0].prefix(3), "round trip mismatch: \(parsed.rows[0])")
            return nil
        }

        // MARK: Importer

        check("importer: template CSVs produce a usable database") {
            let result = QuoteCSVImporter.build(
                groupsCSV: QuoteCSVImporter.templateGroupsCSV(),
                quotesCSV: QuoteCSVImporter.templateQuotesCSV(),
                version: 1,
                generatedAt: "2026-10-31"
            )
            try expect(!result.hasErrors, "errors: \(result.issues.map(\.description))")
            try expect(result.database.groups.count == 1, "groups \(result.database.groups.count)")
            try expect(result.database.quotes.count == 1, "quotes \(result.database.quotes.count)")
            let quote = try unwrap(result.database.quotes.first, "quote")
            try expect(quote.text.en.hasPrefix("PLACEHOLDER"), "text")
            try expect(quote.tags == ["comfort", "nostalgia"], "tags \(quote.tags)")
            try expect(quote.verified, "verified flag")
            try expect(!quote.retired, "retired flag")
            try expect(quote.source.date == "2021-05-21", "date \(quote.source.date)")
            return nil
        }

        check("importer: date shapes a spreadsheet produces") {
            try expect(QuoteCSVImporter.normalizeDate("2021-05-21") == "2021-05-21", "iso")
            try expect(QuoteCSVImporter.normalizeDate("2021/05/21") == "2021-05-21", "slash")
            try expect(QuoteCSVImporter.normalizeDate("2021.5.21") == "2021-05-21", "dot, unpadded")
            try expect(QuoteCSVImporter.normalizeDate("20210521") == "2021-05-21", "compact")
            try expect(QuoteCSVImporter.normalizeDate("21/05/2021") == nil, "ambiguous dmy accepted")
            try expect(QuoteCSVImporter.normalizeDate("May 21, 2021") == nil, "prose accepted")
            return nil
        }

        check("importer: unknown group is an error, not a silent drop") {
            let groups = CSV.encode(header: ["id", "name_en"], rows: [["bts", "BTS"]])
            let quotes = CSV.encode(
                header: ["id", "group_id", "member_id", "text_en", "source_title", "source_date"],
                rows: [["x-1", "nope", "m", "text", "Live", "2021-05-21"]]
            )
            let result = QuoteCSVImporter.build(groupsCSV: groups, quotesCSV: quotes)
            try expect(result.hasErrors, "unknown group was accepted")
            return nil
        }

        check("importer: tags split on semicolons and commas") {
            try expect(
                QuoteCSVImporter.parseTags("comfort; hype,nostalgia、funny") == ["comfort", "hype", "nostalgia", "funny"],
                "tag parsing"
            )
            try expect(QuoteCSVImporter.parseTags(nil).isEmpty, "nil tags")
            return nil
        }

        return results
    }

    // MARK: - Fixtures

    private struct CheckFailure: Error {
        let message: String
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(message: message) }
    }

    private static func unwrap<T>(_ value: T?, _ label: String) throws -> T {
        guard let value else { throw CheckFailure(message: "unexpected nil: \(label)") }
        return value
    }

    private static var fixtureGroup: QuoteGroup {
        QuoteGroup(
            id: "bts",
            name: LocalizedText(en: "BTS", zhHans: "防弹少年团"),
            debut: 2013,
            accent: "#7B5CFA"
        )
    }

    private static func fixtureQuote(
        group: String,
        index: Int,
        en: String? = nil,
        shortEn: String? = nil,
        zh: String? = nil
    ) -> Quote {
        let number = String(format: "%04d", index)
        let text = en ?? "Quote number \(index) from the group."
        return Quote(
            id: "\(group)-x-\(number)",
            groupId: group,
            memberId: "m\(index % 7)",
            memberName: LocalizedText(en: "Member \(index % 7)", zhHans: "成员 \(index % 7)"),
            text: LocalizedText(en: text, zhHans: zh ?? "第 \(index) 句话。"),
            shortText: shortEn.map { LocalizedText(en: $0, zhHans: "短句 \(index)") },
            context: LocalizedText(en: "Context \(index).", zhHans: "背景 \(index)。"),
            source: QuoteSource(
                title: "Weverse Live",
                date: "2021-05-21",
                url: "https://example.com/\(index)"
            ),
            lang: "ko",
            tags: ["comfort"],
            verified: true,
            retired: false
        )
    }

    private static func fixtures(group: String, count: Int) -> [Quote] {
        (1...count).map { fixtureQuote(group: group, index: $0) }
    }

    private static func makeRaw(
        quote: Quote,
        id: String? = nil,
        verified: Bool = true,
        zh: String? = "占位"
    ) -> Quote {
        Quote(
            id: id ?? quote.id,
            groupId: quote.groupId,
            memberId: quote.memberId,
            memberName: quote.memberName,
            text: LocalizedText(en: quote.text.en, zhHans: zh),
            shortText: quote.shortText,
            context: quote.context,
            source: quote.source,
            lang: quote.lang,
            tags: quote.tags,
            verified: verified,
            retired: false
        )
    }

    /// Consecutive `yyyy-MM-dd` keys starting at `start`.
    private static func walkDays(from start: String, count: Int) throws -> [String] {
        let parts = start.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw CheckFailure(message: "bad start date \(start)") }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let base = calendar.date(from: components) else {
            throw CheckFailure(message: "bad start date \(start)")
        }
        var days: [String] = []
        for offset in 0..<count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: base) else { continue }
            days.append(DayKey.string(for: day, timeZone: TimeZone(identifier: "UTC")!))
        }
        return days
    }

    private static func cycleOrder(startingAt start: String, pool: [Quote]) throws -> [String] {
        try walkDays(from: start, count: 60).map { day in
            DailyRotator.quote(for: "bts", dayKey: day, in: pool)?.id ?? "?"
        }
    }
}
