import Foundation

/// An absolute day number (Julian Day Number) derived from a `yyyy-MM-dd` key.
///
/// Pure integer arithmetic so it never depends on `Calendar`, the device time zone, or DST. That
/// matters because the widget extension and the app are separate processes and must agree on
/// "which day is it" without sharing any state.
public struct DayNumber: Hashable, Sendable, Comparable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    /// Fliegel–Van Flandern. Positive years only, which is all this app will ever need.
    public init?(dayKey: String) {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        let jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        self.value = jdn
    }

    public static func < (lhs: DayNumber, rhs: DayNumber) -> Bool {
        lhs.value < rhs.value
    }
}

/// Deterministic PRNG. Small, fast, and stable across platforms and Swift versions — unlike
/// `SystemRandomNumberGenerator` or `Hasher`, both of which are intentionally unpredictable.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
