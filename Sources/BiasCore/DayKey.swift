import Foundation

/// Day boundaries for the daily rotation.
///
/// Deliberately uses the device's own time zone rather than a fixed one: a fan in Seoul and a fan
/// in Shanghai should both see a new quote when *their* day turns over. The trade-off is that a
/// traveller crossing time zones may see the quote change early, which is harmless.
public enum DayKey {
    public static func string(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let year = c.year ?? 1970
        let month = c.month ?? 1
        let day = c.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Midnight at the start of `date`'s day, in the given time zone.
    public static func startOfDay(for date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    public static func date(byAddingDays days: Int, to date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}
