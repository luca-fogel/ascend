import Foundation

/// Turns "the user did a medium daily task on a 12-day streak" into a number.
///
/// The streak multiplier is capped on purpose. Uncapped, a 200-day streak would pay 11x and
/// make every new goal feel worthless next to the old one; capping at 2x means a streak is
/// worth chasing for about three weeks and then stops distorting the economy.
public struct XPFormula: Sendable, Equatable, Hashable {
    public let streakBonusPerDay: Double
    public let maxStreakMultiplier: Double

    public init(streakBonusPerDay: Double = 0.05, maxStreakMultiplier: Double = 2.0) {
        self.streakBonusPerDay = streakBonusPerDay
        self.maxStreakMultiplier = maxStreakMultiplier
    }

    public static let standard = XPFormula()

    /// 1.0 at no streak, +5%/day, hard-capped at 2x (reached at a 20-day streak).
    public func streakMultiplier(forStreak streak: Int) -> Double {
        guard streak > 0 else { return 1 }
        return min(1 + streakBonusPerDay * Double(streak), maxStreakMultiplier)
    }

    /// Rounded once, at the end, and never below 1 -- a completed task that paid zero XP
    /// reads as a bug to the user even when the arithmetic is right.
    public func xp(difficulty: TaskDifficulty, cadence: TaskCadence, streak: Int) -> Int {
        let effectiveStreak = cadence.buildsStreak ? streak : 0
        let raw = Double(difficulty.baseXP)
            * streakMultiplier(forStreak: effectiveStreak)
            * cadence.xpWeight
        return max(1, Int(raw.rounded()))
    }
}
