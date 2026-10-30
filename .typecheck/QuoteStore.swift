import Foundation

/// Read-only, indexed view over the bundled quote database.
///
/// There is no network and no account: the whole content set ships inside the binary, so the
/// widget can never show a loading state or an error.
public struct QuoteStore: Sendable {
    public let database: QuoteDatabase

    private let groupsById: [String: QuoteGroup]
    /// Non-retired quotes per group, sorted by id for deterministic behaviour.
    private let activeByGroup: [String: [Quote]]

    public init(database: QuoteDatabase) {
        self.database = database

        var groupsById: [String: QuoteGroup] = [:]
        for group in database.groups where groupsById[group.id] == nil {
            groupsById[group.id] = group
        }
        self.groupsById = groupsById

        var active: [String: [Quote]] = [:]
        for quote in database.quotes where !quote.retired {
            active[quote.groupId, default: []].append(quote)
        }
        for key in active.keys {
            active[key]?.sort { $0.id < $1.id }
        }
        self.activeByGroup = active
    }

    public init(data: Data) throws {
        let decoder = JSONDecoder()
        self.init(database: try decoder.decode(QuoteDatabase.self, from: data))
    }

    // MARK: - Groups

    public var groups: [QuoteGroup] {
        database.groups
    }

    public func group(for id: String) -> QuoteGroup? {
        groupsById[id]
    }

    public func quotes(in groupId: String) -> [Quote] {
        activeByGroup[groupId] ?? []
    }

    public func quoteCount(in groupId: String) -> Int {
        quotes(in: groupId).count
    }

    /// Groups that have enough content to be worth showing a fan. The gate that stops the app from
    /// launching with a group that repeats within two weeks.
    public func groupsMeetingMinimum(minimum: Int = 60) -> [QuoteGroup] {
        database.groups.filter { quoteCount(in: $0.id) >= minimum }
    }

    // MARK: - Rotation

    public func quote(for groupId: String, dayKey: String) -> Quote? {
        DailyRotator.quote(for: groupId, dayKey: dayKey, in: quotes(in: groupId))
    }

    public func quote(for groupId: String, date: Date, timeZone: TimeZone = .current) -> Quote? {
        DailyRotator.quote(
            for: groupId,
            dayKey: DayKey.string(for: date, timeZone: timeZone),
            in: quotes(in: groupId)
        )
    }

    /// Pre-computed days for a widget timeline. Starts at the beginning of `date`'s day so the
    /// switch happens at local midnight rather than at whatever time the app last opened.
    public func upcomingQuotes(
        for groupId: String,
        from date: Date,
        dayCount: Int,
        timeZone: TimeZone = .current
    ) -> [(day: Date, quote: Quote)] {
        let start = DayKey.startOfDay(for: date, timeZone: timeZone)
        var result: [(day: Date, quote: Quote)] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        for offset in 0..<max(0, dayCount) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if let quote = quote(for: groupId, date: day, timeZone: timeZone) {
                result.append((day, quote))
            }
        }
        return result
    }

    // MARK: - Browsing

    /// Archive contents, newest first by source date, for the given groups.
    public func archive(groupIds: Set<String>, searchText: String = "") -> [Quote] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return database.quotes
            .filter { !$0.retired && (groupIds.isEmpty || groupIds.contains($0.groupId)) }
            .filter { quote in
                guard !needle.isEmpty else { return true }
                return quote.text.en.lowercased().contains(needle)
                    || (quote.text.zhHans ?? "").contains(needle)
                    || quote.memberName.en.lowercased().contains(needle)
            }
            .sorted { lhs, rhs in
                if lhs.source.date == rhs.source.date { return lhs.id < rhs.id }
                return lhs.source.date > rhs.source.date
            }
    }

    public func distinctMembers(in groupId: String) -> [LocalizedText] {
        var seen = Set<String>()
        var members: [LocalizedText] = []
        for quote in quotes(in: groupId) where !seen.contains(quote.memberId) {
            seen.insert(quote.memberId)
            members.append(quote.memberName)
        }
        return members
    }
}
