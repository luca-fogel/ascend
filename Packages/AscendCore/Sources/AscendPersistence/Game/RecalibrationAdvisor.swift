import Foundation
import SwiftData
import AscendDomain

/// Decides when a goal has drifted far enough to be worth re-planning.
///
/// This is the trigger the brief's "dynamic AI re-routing" needs: the provider could always
/// generate a side-quest, but nothing was ever asking it to. The judgement is deliberately
/// conservative -- offering to rewrite someone's plan the first time they skip a day would be
/// both annoying and patronising.
@MainActor
public enum RecalibrationAdvisor {

    /// Consecutive missed game days before a goal is considered off the rails.
    public static let missedDayThreshold = 3

    /// How many days in a row a goal's daily steps have gone undone, or `nil` if it is fine.
    ///
    /// Measured from the ledger rather than task state, because `.missed` is set once by a
    /// rollover and does not say *how long* the drift has lasted.
    public static func missedDays(for goal: Goal,
                                 profile: UserProfile,
                                 context: ModelContext,
                                 streaks: StreakCalculator,
                                 now: Date) throws -> Int? {
        guard goal.status == .active else { return nil }
        let dailyTasks = goal.allTasks.filter { $0.cadence.accruesMissDamage }
        guard !dailyTasks.isEmpty else { return nil }

        // The most recent day any of this goal's steps were completed.
        var latestKey: Int?
        for task in dailyTasks {
            let idString = task.uuid.uuidString
            let descriptor = FetchDescriptor<CompletionLog>(
                predicate: #Predicate { $0.sourceIDString == idString && $0.wasUndone == false }
            )
            for log in try context.fetch(descriptor) {
                latestKey = max(latestKey ?? log.gameDayKey, log.gameDayKey)
            }
        }

        // Never started counts from when the goal was created, so a goal abandoned on day one
        // is still noticed.
        let since = latestKey == nil ? goal.createdAt : nil
        let elapsed: Int
        if let since {
            elapsed = streaks.elapsedGameDays(from: since, to: now)
        } else {
            // Walks raw instants, not day starts. `gameDayKey(for:)` normalises its argument,
            // so stepping back through already-normalised day starts would normalise twice and
            // report every gap one day short -- and a gap that never matched would run to the
            // loop bound and look like 60 days of drift.
            var days = 0
            var cursor = now
            while days < 60 {
                if streaks.gameDayKey(for: cursor) == latestKey { break }
                days += 1
                guard let previous = streaks.calendar.date(byAdding: .day, value: -1, to: cursor)
                else { break }
                cursor = previous
            }
            elapsed = days
        }
        return elapsed >= missedDayThreshold ? elapsed : nil
    }

    /// The goal most in need of a way back, if any.
    public static func goalNeedingRecalibration(profile: UserProfile,
                                                context: ModelContext,
                                                streaks: StreakCalculator,
                                                now: Date) throws -> (goal: Goal, missedDays: Int)? {
        var worst: (Goal, Int)?
        for goal in profile.goals where goal.status == .active {
            if let days = try missedDays(for: goal, profile: profile, context: context,
                                         streaks: streaks, now: now) {
                if days > (worst?.1 ?? 0) { worst = (goal, days) }
            }
        }
        guard let worst else { return nil }
        return (worst.0, worst.1)
    }

    /// Builds the request the provider needs.
    public static func request(for goal: Goal, missedDays: Int) -> RecalibrationRequest {
        RecalibrationRequest(
            goalTitle: goal.title,
            goalSummary: goal.detail,
            missedDays: missedDays,
            remainingMilestoneTitles: goal.orderedMilestones
                .filter { $0.status != .completed }
                .map(\.title),
            minutesPerDay: goal.minutesPerDay)
    }
}
