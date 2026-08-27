import Foundation

/// What missing a day costs.
///
/// The per-rollover cap is the important part. Without it, opening the app after a two-week
/// holiday resolves fourteen days of misses in one go and kills a level-40 character
/// instantly -- which is precisely the moment a returning user decides whether to keep the
/// app. Damage is therefore capped as a *fraction of max HP per rollover*, so coming back
/// always hurts, and never one-shots.
public struct DamageFormula: Sendable, Equatable, Hashable {
    public let escalationPerMissedDay: Double
    public let maxEscalation: Double
    public let perRolloverCapFraction: Double

    public init(escalationPerMissedDay: Double = 0.25,
                maxEscalation: Double = 2.0,
                perRolloverCapFraction: Double = 0.40) {
        self.escalationPerMissedDay = escalationPerMissedDay
        self.maxEscalation = maxEscalation
        self.perRolloverCapFraction = perRolloverCapFraction
    }

    public static let standard = DamageFormula()

    /// Consecutive misses hurt progressively more, up to a ceiling.
    public func escalation(forConsecutiveMissedDays days: Int) -> Double {
        guard days > 1 else { return 1 }
        return min(1 + escalationPerMissedDay * Double(days - 1), maxEscalation)
    }

    public func damage(difficulty: TaskDifficulty, consecutiveMissedDays: Int) -> Int {
        let raw = Double(difficulty.missDamage) * escalation(forConsecutiveMissedDays: consecutiveMissedDays)
        return max(1, Int(raw.rounded()))
    }

    /// The most HP a single rollover may remove, whatever the backlog.
    public func cap(forMaxHP maxHP: Int) -> Int {
        max(1, Int((Double(maxHP) * perRolloverCapFraction).rounded()))
    }

    public func capped(_ rawDamage: Int, maxHP: Int) -> Int {
        min(max(0, rawDamage), cap(forMaxHP: maxHP))
    }
}
