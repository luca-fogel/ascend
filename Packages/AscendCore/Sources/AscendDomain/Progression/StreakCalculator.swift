import Foundation

/// Streaks and rollovers in terms of *game days*, not calendar days.
///
/// A game day starts at `dayStartHour` (default 04:00), because someone finishing a task at
/// 01:30 is still working on Tuesday as far as they are concerned, and charging them for
/// missing Wednesday would be wrong.
///
/// All arithmetic goes through `Calendar` rather than adding 86_400 seconds, so the two days
/// a year that are 23 or 25 hours long behave correctly instead of silently shifting every
/// streak by one.
public struct StreakCalculator: Sendable {
    public let calendar: Calendar
    public let dayStartHour: Int

    public init(calendar: Calendar = .current, dayStartHour: Int = 4) {
        self.calendar = calendar
        self.dayStartHour = max(0, min(dayStartHour, 23))
    }

    /// The start of the game day an instant belongs to.
    public func gameDay(for date: Date) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    /// Whole game days between two instants. Negative if `end` precedes `start`.
    public func elapsedGameDays(from start: Date, to end: Date) -> Int {
        let a = gameDay(for: start)
        let b = gameDay(for: end)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    public func gameDay(offsetBy days: Int, from date: Date) -> Date {
        let base = gameDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: base) ?? base
    }

    /// Consecutive completed game days ending at `date`.
    ///
    /// Today counts if it has a completion, but *not having done it yet today does not break
    /// the streak* -- the run is measured from yesterday instead. Without that grace every
    /// streak in the app would read as 0 each morning until the user tapped something.
    public func streak(endingOn date: Date, completionDates: [Date]) -> Int {
        guard !completionDates.isEmpty else { return 0 }
        let completed = Set(completionDates.map { gameDay(for: $0) })
        let today = gameDay(for: date)

        var cursor = completed.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var streak = 0
        while completed.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Whether a completion exists on the game day containing `date`.
    public func hasCompletion(on date: Date, completionDates: [Date]) -> Bool {
        let target = gameDay(for: date)
        return completionDates.contains { gameDay(for: $0) == target }
    }

    // MARK: - Frozen day keys

    /// A game day as `yyyymmdd`, e.g. `20260827`.
    ///
    /// Persisted by `CompletionLog` at write time so that changing timezone cannot re-bucket
    /// history. Sortable and comparable as a plain `Int`, which is also what makes it usable
    /// in a `#Predicate`.
    public func gameDayKey(for date: Date) -> Int {
        key(ofGameDayStart: gameDay(for: date))
    }

    /// The key of a day start that has *already* been normalised by `gameDay(for:)`.
    ///
    /// **Use this, not `gameDayKey(for:)`, when you are holding a value that came out of
    /// `gameDay(for:)`.** Feeding a day start back through the normaliser subtracts
    /// `dayStartHour` from midnight and lands in the previous day. Two separate call sites have
    /// now made exactly that mistake, and both times it presented as an off-by-one in a loop
    /// rather than as a double-normalisation, which is why this is public and named for the
    /// precondition it requires.
    public func key(ofGameDayStart dayStart: Date) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: dayStart)
        return (parts.year ?? 1970) * 10_000 + (parts.month ?? 1) * 100 + (parts.day ?? 1)
    }

    /// Consecutive completed game days ending at `date`, computed from frozen day keys.
    ///
    /// The authoritative overload. The `Date`-based one above re-derives buckets on every read
    /// and exists only for callers that have not stored keys.
    public func streak(endingOn date: Date, completedDayKeys: Set<Int>) -> Int {
        guard !completedDayKeys.isEmpty else { return 0 }
        let today = gameDay(for: date)
        var cursor = completedDayKeys.contains(key(ofGameDayStart: today))
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var streak = 0
        while completedDayKeys.contains(key(ofGameDayStart: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
