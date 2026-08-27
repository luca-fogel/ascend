import Testing
import Foundation
@testable import AscendDomain

@Suite("Streak calculator")
struct StreakCalculatorTests {

    /// A fixed calendar, because a test that depends on the machine's timezone is a test that
    /// fails in CI for reasons unrelated to the code.
    static func calendar(_ identifier: String = "Europe/London") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    static func date(_ string: String, zone: String = "Europe/London") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: zone)!
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.date(from: string)!
    }

    // MARK: - The 4am cutoff

    @Test("01:30 still belongs to the previous day -- the reason the cutoff exists")
    func lateNightBelongsToYesterday() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        // Someone finishing at half one on Tuesday morning is still working on Monday.
        #expect(streaks.gameDayKey(for: Self.date("2026-03-10 01:30")) == 20260309)
        #expect(streaks.gameDayKey(for: Self.date("2026-03-10 03:59")) == 20260309)
        // 04:00 is where the new day starts.
        #expect(streaks.gameDayKey(for: Self.date("2026-03-10 04:00")) == 20260310)
        #expect(streaks.gameDayKey(for: Self.date("2026-03-10 23:59")) == 20260310)
    }

    @Test("a zero cutoff makes game days ordinary calendar days")
    func zeroCutoffIsCalendarDay() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 0)
        #expect(streaks.gameDayKey(for: Self.date("2026-03-10 00:01")) == 20260310)
        #expect(streaks.gameDayKey(for: Self.date("2026-03-10 23:59")) == 20260310)
    }

    @Test("an out-of-range cutoff hour is clamped rather than producing nonsense days")
    func cutoffIsClamped() {
        #expect(StreakCalculator(dayStartHour: -5).dayStartHour == 0)
        #expect(StreakCalculator(dayStartHour: 99).dayStartHour == 23)
    }

    // MARK: - Daylight saving

    @Test("the 23-hour spring-forward day does not shift the game day")
    func springForwardIsHandled() {
        // UK clocks jump 01:00 -> 02:00 on 2026-03-29, so that day is 23 hours long. Doing
        // date arithmetic in seconds instead of through Calendar shifts every streak by one
        // here; going through Calendar does not.
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        #expect(streaks.gameDayKey(for: Self.date("2026-03-29 03:30")) == 20260328)
        #expect(streaks.gameDayKey(for: Self.date("2026-03-29 05:00")) == 20260329)
        #expect(streaks.elapsedGameDays(from: Self.date("2026-03-28 12:00"),
                                        to: Self.date("2026-03-29 12:00")) == 1)
    }

    @Test("the 25-hour autumn day counts as exactly one game day, not two")
    func fallBackIsHandled() {
        // UK clocks go 02:00 -> 01:00 on 2026-10-25: a 25-hour day.
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        #expect(streaks.elapsedGameDays(from: Self.date("2026-10-24 12:00"),
                                        to: Self.date("2026-10-25 12:00")) == 1)
        #expect(streaks.elapsedGameDays(from: Self.date("2026-10-25 12:00"),
                                        to: Self.date("2026-10-26 12:00")) == 1)
    }

    // MARK: - Streak counting

    @Test("consecutive days accumulate")
    func consecutiveDaysCount() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        let keys: Set<Int> = [20260306, 20260307, 20260308, 20260309, 20260310]
        #expect(streaks.streak(endingOn: Self.date("2026-03-10 20:00"), completedDayKeys: keys) == 5)
    }

    @Test("a gap ends the streak at the gap, not at the beginning of history")
    func gapEndsStreak() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        // 8th is missing, so only the 9th and 10th count.
        let keys: Set<Int> = [20260301, 20260302, 20260309, 20260310]
        #expect(streaks.streak(endingOn: Self.date("2026-03-10 20:00"), completedDayKeys: keys) == 2)
    }

    @Test("not having done it yet today does not break the streak -- the morning-grace rule")
    func todayIsGraced() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        // Nothing logged for the 10th. Without the grace period, every streak in the app
        // would read 0 each morning until the user tapped something.
        let keys: Set<Int> = [20260307, 20260308, 20260309]
        #expect(streaks.streak(endingOn: Self.date("2026-03-10 09:00"), completedDayKeys: keys) == 3)
    }

    @Test("missing both today and yesterday does break the streak")
    func twoMissedDaysBreakIt() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        let keys: Set<Int> = [20260307, 20260308]
        #expect(streaks.streak(endingOn: Self.date("2026-03-10 09:00"), completedDayKeys: keys) == 0)
    }

    @Test("no history is a streak of zero, not a crash")
    func emptyHistory() {
        let streaks = StreakCalculator(calendar: Self.calendar())
        #expect(streaks.streak(endingOn: Date(), completedDayKeys: []) == 0)
        #expect(streaks.streak(endingOn: Date(), completionDates: []) == 0)
    }

    @Test("a streak of 400 days is counted without the loop running away")
    func longStreak() {
        let calendar = Self.calendar()
        let streaks = StreakCalculator(calendar: calendar, dayStartHour: 4)
        let end = Self.date("2026-03-10 20:00")
        var keys = Set<Int>()
        for offset in 0..<400 {
            let day = calendar.date(byAdding: .day, value: -offset, to: end)!
            keys.insert(streaks.gameDayKey(for: day))
        }
        #expect(streaks.streak(endingOn: end, completedDayKeys: keys) == 400)
    }

    // MARK: - The bug frozen keys exist to prevent

    @Test("a stored day key is immune to the user changing timezone, unlike a re-derived one")
    func frozenKeysSurviveTimezoneTravel() {
        // A completion at 02:00 London time on the 10th belongs to game day the 9th.
        let completion = Self.date("2026-03-10 02:00", zone: "Europe/London")

        let london = StreakCalculator(calendar: Self.calendar("Europe/London"), dayStartHour: 4)
        let tokyo = StreakCalculator(calendar: Self.calendar("Asia/Tokyo"), dayStartHour: 4)

        let keyAtHome = london.gameDayKey(for: completion)
        let keyAfterFlying = tokyo.gameDayKey(for: completion)

        // Re-deriving the bucket from the raw instant gives a *different* day once the
        // timezone changes -- which is exactly how a 40-day streak silently splits into two
        // 20-day ones after a long-haul flight.
        #expect(keyAtHome != keyAfterFlying)

        // Because CompletionLog stores the key computed at write time, history is immutable:
        // the streak is counted from frozen keys and does not move.
        let frozen: Set<Int> = [20260307, 20260308, keyAtHome]
        #expect(london.streak(endingOn: Self.date("2026-03-10 09:00"), completedDayKeys: frozen) == 3)
    }

    @Test("elapsed game days is zero within a day, and negative if time runs backwards")
    func elapsedDays() {
        let streaks = StreakCalculator(calendar: Self.calendar(), dayStartHour: 4)
        #expect(streaks.elapsedGameDays(from: Self.date("2026-03-10 05:00"),
                                        to: Self.date("2026-03-10 23:00")) == 0)
        #expect(streaks.elapsedGameDays(from: Self.date("2026-03-10 05:00"),
                                        to: Self.date("2026-03-15 05:00")) == 5)
        // A user who moved their device clock backwards. The engine must notice, not
        // underflow into a huge positive count.
        #expect(streaks.elapsedGameDays(from: Self.date("2026-03-15 05:00"),
                                        to: Self.date("2026-03-10 05:00")) == -5)
    }

    @Test("the Date-based overload agrees with the frozen-key one when the timezone is stable")
    func overloadsAgree() {
        let calendar = Self.calendar()
        let streaks = StreakCalculator(calendar: calendar, dayStartHour: 4)
        let end = Self.date("2026-03-10 20:00")
        let dates = (0..<6).map { calendar.date(byAdding: .day, value: -$0, to: end)! }
        let keys = Set(dates.map { streaks.gameDayKey(for: $0) })
        #expect(streaks.streak(endingOn: end, completionDates: dates)
                == streaks.streak(endingOn: end, completedDayKeys: keys))
    }
}
