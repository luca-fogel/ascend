import Foundation
import SwiftData
import AscendDomain

// MARK: - Day rollover
//
// The "cron": the thing that notices you did not show up. Everything here is about being
// consequential without being punitive, because this is the code path a returning user meets
// first, and it decides whether they stay.

extension GameManager {

    /// Closes out every game day that has ended since the last rollover.
    ///
    /// Four properties, each one a bug that was designed out rather than found later:
    ///
    /// 1. **Idempotent.** Guarded by `lastRolloverDate`, so the app-lifecycle events that call
    ///    this -- and genuinely do fire more than once -- cannot charge twice for one day.
    /// 2. **The damage cap is per invocation, not per day.** This is the whole point of the
    ///    cap and it is easy to get backwards: at 40% of max HP *per day*, five neglected days
    ///    resolve to 200% and kill any character outright, which is precisely the case the cap
    ///    exists to prevent. Capping the call means returning after two weeks away always
    ///    hurts and never one-shots; death takes three separate neglectful returns.
    /// 3. **Bounded work.** At most `maxRolloverDaysProcessed` days, and it processes the most
    ///    *recent* ones. Someone returning after a year owes a month, not 365 iterations --
    ///    and charging for the oldest days while ignoring the newest would be both slower and
    ///    wrong.
    /// 4. **A backwards clock is not a windfall.** If `now` precedes the last rollover the
    ///    user has moved their device clock; the marker is reset and nothing is charged,
    ///    rather than letting a negative day count reach the loop.
    public func processDayRolloverIfNeeded() throws -> [RolloverReport] {
        guard !rollInProgress else { return [] }
        rollInProgress = true
        defer { rollInProgress = false }

        let profile = try requireProfile()
        let now = clock.now
        let streaks = streakCalculator(for: profile)
        let last = profile.lastRolloverDate ?? profile.createdAt

        if now < last {
            try store.transaction { profile.lastRolloverDate = now }
            return []
        }

        let elapsed = streaks.elapsedGameDays(from: last, to: now)
        guard elapsed > 0 else { return [] }

        let daysToProcess = min(elapsed, gameRules.maxRolloverDaysProcessed)
        let skipped = elapsed - daysToProcess
        let firstDay = streaks.gameDay(offsetBy: skipped, from: last)

        var reports: [RolloverReport] = []
        var damageBudget = gameRules.damage.cap(
            forMaxHP: gameRules.maxHP(
                forCharacterLevel: gameRules.characterCurve.level(forTotalXP: profile.totalXP)
            )
        )

        try store.transaction {
            for offset in 0..<daysToProcess {
                let day = streaks.gameDay(offsetBy: offset, from: firstDay)
                var report = try closeOut(day: day, for: profile, streaks: streaks, budget: &damageBudget)

                if profile.currentHP <= 0 {
                    applyDefeat(to: profile)
                    report = RolloverReport(gameDay: report.gameDay,
                                            missedTitles: report.missedTitles,
                                            rawDamage: report.rawDamage,
                                            appliedDamage: report.appliedDamage,
                                            healed: report.healed,
                                            brokenStreakTitles: report.brokenStreakTitles,
                                            wasDefeated: true)
                    // A defeat resets HP, so the rest of the backlog would land on a full bar
                    // and could kill twice in one call. One defeat per rollover.
                    reports.append(report)
                    break
                }
                reports.append(report)
            }
            profile.lastRolloverDate = now
            refreshHabitStreakCaches(for: profile, streaks: streaks)
        }
        return reports
    }

    /// Resolves one ended game day, spending from the shared damage budget.
    private func closeOut(day: Date,
                          for profile: UserProfile,
                          streaks: StreakCalculator,
                          budget: inout Int) throws -> RolloverReport {
        let dayKey = streaks.gameDayKey(for: day)
        var missedTitles: [String] = []
        var brokenStreakTitles: [String] = []
        var rawDamage = 0

        // Daily steps inside active goals. `accruesMissDamage` is what keeps weekly steps,
        // one-shots and paused goals out of this -- charging for a goal the user deliberately
        // paused is the fastest way to make the app feel like an antagonist.
        let dueTasks = profile.goals
            .filter { $0.status == .active }
            .flatMap(\.allTasks)
            .filter { $0.cadence.accruesMissDamage }

        for task in dueTasks where task.state == .pending || task.state == .missed {
            let keys = try completedDayKeys(forSourceID: task.uuid)
            guard !keys.contains(dayKey) else { continue }
            let consecutive = consecutiveMissedDays(endingOn: day,
                                                    notBefore: task.createdAt,
                                                    completedKeys: keys,
                                                    streaks: streaks)
            rawDamage += gameRules.damage.damage(difficulty: task.difficulty,
                                                 consecutiveMissedDays: consecutive)
            missedTitles.append(task.title)
            if task.state == .pending { task.state = .missed }
        }

        for habit in profile.habits where habit.accruesMissDamage {
            let keys = try completedDayKeys(forSourceID: habit.uuid)
            guard !keys.contains(dayKey) else { continue }
            let consecutive = consecutiveMissedDays(endingOn: day,
                                                    notBefore: habit.createdAt,
                                                    completedKeys: keys,
                                                    streaks: streaks)
            rawDamage += gameRules.damage.damage(difficulty: habit.difficulty,
                                                 consecutiveMissedDays: consecutive)
            missedTitles.append(habit.title)
            if habit.currentStreak > 0 { brokenStreakTitles.append(habit.title) }
        }

        // Spend from the per-invocation budget. Once it is exhausted, later days in the same
        // call still report what they *would* have cost -- `wasDamageCapped` is how the UI can
        // say "damage reduced" instead of pretending the backlog was smaller than it was.
        let applied = min(rawDamage, max(0, budget))
        budget -= applied

        let level = gameRules.characterCurve.level(forTotalXP: profile.totalXP)
        let maxHP = gameRules.maxHP(forCharacterLevel: level)
        var healed = 0

        if applied > 0 {
            profile.currentHP = profile.currentHP - applied
        } else if missedTitles.isEmpty, try hadAnyCompletion(on: dayKey) {
            let before = profile.currentHP
            profile.currentHP = min(maxHP, before + gameRules.healAmount(forMaxHP: maxHP))
            healed = profile.currentHP - before
        }

        return RolloverReport(gameDay: day,
                              missedTitles: missedTitles,
                              rawDamage: rawDamage,
                              appliedDamage: applied,
                              healed: healed,
                              brokenStreakTitles: brokenStreakTitles,
                              wasDefeated: false)
    }

    /// How many game days in a row, ending at `day`, have no completion. Drives escalation.
    ///
    /// `notBefore` is load-bearing and was added because its absence was a real bug: a task
    /// that has *never* been completed has no completion on any earlier day either, so the
    /// walk ran back to the escalation ceiling and charged maximum damage the very first time
    /// a brand-new step was missed. Neglect can only be counted from the day the thing
    /// started existing.
    private func consecutiveMissedDays(endingOn day: Date,
                                       notBefore existedSince: Date,
                                       completedKeys: Set<Int>,
                                       streaks: StreakCalculator) -> Int {
        var count = 0
        var cursor = day
        let floorKey = streaks.gameDayKey(for: existedSince)
        // Also bounded by the escalation ceiling: once the multiplier has maxed out, counting
        // further back cannot change the answer.
        while count < 14 {
            let key = streaks.gameDayKey(for: cursor)
            if key < floorKey { break }
            if completedKeys.contains(key) { break }
            count += 1
            guard let previous = streaks.calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return max(1, count)
    }

    private func hadAnyCompletion(on dayKey: Int) throws -> Bool {
        var descriptor = FetchDescriptor<CompletionLog>(
            predicate: #Predicate { $0.gameDayKey == dayKey && $0.wasUndone == false }
        )
        descriptor.fetchLimit = 1
        return !(try store.fetch(descriptor).isEmpty)
    }

    /// HP hit zero.
    ///
    /// The loss is deliberately **bounded and comprehensible**: XP falls to the floor of the
    /// current level, so you lose your progress *toward* the next one and never the level
    /// itself. Two things follow. Character level is monotonic non-decreasing, which keeps
    /// "reached level 10" meaningful and stops a defeat from re-firing achievements. And the
    /// loss cannot be a rounding accident -- demoting a level instead would cost one user 1 XP
    /// and another 574 for the same mistake, which reads as a bug however correct it is.
    private func applyDefeat(to profile: UserProfile) {
        let level = gameRules.characterCurve.level(forTotalXP: profile.totalXP)
        profile.totalXP = gameRules.characterCurve.totalXP(toReach: level)
        profile.gold = Int(Double(profile.gold) * (1 - gameRules.defeatGoldPenaltyFraction))
        profile.currentHP = gameRules.maxHP(forCharacterLevel: level)
        profile.defeatCount += 1
        for habit in profile.habits { habit.currentStreak = 0 }
    }

    /// Rewrites the denormalised streak counters on `Habit` from the ledger.
    ///
    /// `CompletionLog` is the authority; these are a cache, and this is where it is repaired.
    /// The cache exists because a habit list would otherwise rescan every habit's whole
    /// history on each SwiftUI body evaluation, and `@Observable` re-runs bodies often.
    /// `GameManagerTests` asserts the cached value equals the recomputed one, so the
    /// denormalisation is checked rather than trusted.
    private func refreshHabitStreakCaches(for profile: UserProfile, streaks: StreakCalculator) {
        for habit in profile.habits {
            let keys = (try? completedDayKeys(forSourceID: habit.uuid)) ?? []
            let current = streaks.streak(endingOn: clock.now, completedDayKeys: keys)
            habit.currentStreak = current
            habit.bestStreak = max(habit.bestStreak, current)
        }
    }
}
