import Foundation

/// Picks the quote of the day for a group.
///
/// ## Why not `hash(group|date) % count`
///
/// That is what most "quote of the day" apps do, and it has two problems here:
///
/// 1. `count` changes every time a quote is added, so publishing ten new quotes reshuffles *every*
///    day, including the widget timeline already on a fan's Home Screen.
/// 2. It happily shows the same quote two days running — with 60 quotes that happens roughly every
///    two weeks, and it reads as a bug.
///
/// ## What this does instead: deterministic cycles
///
/// The calendar is cut into cycles of `N` days, where `N` is the number of active quotes for the
/// group. Each cycle is a seeded Fisher–Yates shuffle of the whole pool, and day `i` of the cycle
/// takes element `i` of that shuffle.
///
/// - **No repeats inside a cycle.** A fan sees every quote exactly once before any repeats. This is
///   the behaviour people actually want from "a new quote every day".
/// - **Different order every cycle.** Cycles are seeded by `(groupId, cycleIndex)`, so the second
///   pass through the pool is not the same sequence as the first.
/// - **Deterministic.** Pure integer arithmetic and a fixed PRNG. Same answer on every device, in
///   both the app and the widget extension, forever.
/// - **Non-recursive.** No dependence on the previous day's pick, so computing day 10 costs the same
///   as computing day 0.
///
/// ## Accepted trade-offs
///
/// - When the pool size changes (a content update ships), the cycle grid shifts and some days may
///   show a different quote than before. Only "today" and the 10-day widget timeline are observable,
///   so this is invisible in practice.
/// - At a cycle boundary the last quote of cycle *k* can equal the first of cycle *k+1* with
///   probability `1/N`.
public enum DailyRotator {
    public static func quote(for groupId: String, dayKey: String, in pool: [Quote]) -> Quote? {
        guard let dayNumber = DayNumber(dayKey: dayKey) else { return nil }

        let active = pool
            .filter { $0.groupId == groupId && !$0.retired }
            .sorted { $0.id < $1.id }
        guard !active.isEmpty else { return nil }

        let cycleLength = active.count
        let cycleIndex = dayNumber.value / cycleLength
        let position = dayNumber.value % cycleLength

        let order = permutation(
            count: cycleLength,
            seed: StableHash.fnv1a([groupId, String(cycleIndex)])
        )
        return active[order[position]]
    }

    public static func quote(
        for groupId: String,
        date: Date,
        in pool: [Quote],
        timeZone: TimeZone = .current
    ) -> Quote? {
        quote(for: groupId, dayKey: DayKey.string(for: date, timeZone: timeZone), in: pool)
    }

    /// Seeded Fisher–Yates. Returns indices into the pool.
    static func permutation(count: Int, seed: UInt64) -> [Int] {
        guard count > 1 else { return Array(0..<max(count, 0)) }
        var indices = Array(0..<count)
        var rng = SplitMix64(seed: seed)
        var i = count - 1
        while i > 0 {
            let j = Int(rng.next() % UInt64(i + 1))
            indices.swapAt(i, j)
            i -= 1
        }
        return indices
    }
}
