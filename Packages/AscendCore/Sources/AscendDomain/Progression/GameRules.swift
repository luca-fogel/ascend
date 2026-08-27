import Foundation

/// Every tunable number in the game, in one injectable value.
///
/// `GameManager` owns no constants of its own: balance changes are a diff to this file plus
/// a diff to the pinned tests, never a hunt through the engine.
public struct GameRules: Sendable, Equatable, Hashable {
    public let baseMaxHP: Int
    public let hpPerCharacterLevel: Int
    /// Fraction of max HP restored for clearing everything due on a game day.
    public let fullDayHealFraction: Double
    /// Fraction of gold lost on defeat.
    public let defeatGoldPenaltyFraction: Double
    /// Share of a task's XP that also lands on the active boss.
    public let bossDamageFraction: Double
    public let goldPerCompletion: Int
    /// Upper bound on game days a single rollover will reconstruct. A user who returns after
    /// a year gets a month of consequences, not 365 iterations of fetch-and-diff.
    public let maxRolloverDaysProcessed: Int

    public let skillCurve: ProgressionCurve
    public let characterCurve: ProgressionCurve
    public let xp: XPFormula
    public let damage: DamageFormula

    public init(baseMaxHP: Int = 50,
                hpPerCharacterLevel: Int = 5,
                fullDayHealFraction: Double = 0.10,
                defeatGoldPenaltyFraction: Double = 0.5,
                bossDamageFraction: Double = 0.5,
                goldPerCompletion: Int = 3,
                maxRolloverDaysProcessed: Int = 30,
                skillCurve: ProgressionCurve = .skill,
                characterCurve: ProgressionCurve = .character,
                xp: XPFormula = .standard,
                damage: DamageFormula = .standard) {
        self.baseMaxHP = baseMaxHP
        self.hpPerCharacterLevel = hpPerCharacterLevel
        self.fullDayHealFraction = fullDayHealFraction
        self.defeatGoldPenaltyFraction = defeatGoldPenaltyFraction
        self.bossDamageFraction = bossDamageFraction
        self.goldPerCompletion = goldPerCompletion
        self.maxRolloverDaysProcessed = maxRolloverDaysProcessed
        self.skillCurve = skillCurve
        self.characterCurve = characterCurve
        self.xp = xp
        self.damage = damage
    }

    public static let standard = GameRules()

    public func maxHP(forCharacterLevel level: Int) -> Int {
        baseMaxHP + hpPerCharacterLevel * max(0, level - 1)
    }

    public func healAmount(forMaxHP maxHP: Int) -> Int {
        max(1, Int((Double(maxHP) * fullDayHealFraction).rounded()))
    }

    public func bossDamage(forXP xp: Int) -> Int {
        max(1, Int((Double(xp) * bossDamageFraction).rounded()))
    }
}
