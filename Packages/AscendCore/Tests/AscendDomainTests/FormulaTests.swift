import Testing
import Foundation
@testable import AscendDomain

@Suite("XP formula")
struct XPFormulaTests {

    @Test("a task with no streak pays exactly its difficulty's base XP")
    func baseCase() {
        for difficulty in TaskDifficulty.allCases {
            let xp = XPFormula.standard.xp(difficulty: difficulty, cadence: .daily, streak: 0)
            #expect(xp == difficulty.baseXP)
        }
    }

    @Test("the streak multiplier caps at 2x, so a 200-day streak cannot break the economy")
    func multiplierCaps() {
        let formula = XPFormula.standard
        #expect(formula.streakMultiplier(forStreak: 0) == 1)
        #expect(formula.streakMultiplier(forStreak: 10) == 1.5)
        #expect(formula.streakMultiplier(forStreak: 20) == 2.0)
        // The point of the cap: 200 days pays no more than 20 did.
        #expect(formula.streakMultiplier(forStreak: 200) == 2.0)
        #expect(formula.streakMultiplier(forStreak: 20_000) == 2.0)
    }

    @Test("a negative streak is treated as no streak rather than shrinking the reward")
    func negativeStreakIsIgnored() {
        #expect(XPFormula.standard.streakMultiplier(forStreak: -5) == 1)
    }

    @Test("weekly and one-shot steps pay a premium but ignore streaks entirely")
    func cadenceWeighting() {
        let formula = XPFormula.standard
        let weekly = formula.xp(difficulty: .medium, cadence: .weekly, streak: 0)
        #expect(weekly == 32)  // 20 * 1.6

        // A weekly step cannot be done daily, so a streak must not inflate it.
        #expect(formula.xp(difficulty: .medium, cadence: .weekly, streak: 30) == weekly)
        #expect(formula.xp(difficulty: .medium, cadence: .oneShot, streak: 30)
                == formula.xp(difficulty: .medium, cadence: .oneShot, streak: 0))
    }

    @Test("a completed task always pays at least 1 XP, whatever the arithmetic says")
    func neverPaysZero() {
        let stingy = XPFormula(streakBonusPerDay: 0, maxStreakMultiplier: 0)
        #expect(stingy.xp(difficulty: .trivial, cadence: .daily, streak: 0) >= 1)
    }
}

@Suite("Damage formula")
struct DamageFormulaTests {

    @Test("one missed day costs exactly the difficulty's damage, with no escalation")
    func singleMiss() {
        for difficulty in TaskDifficulty.allCases {
            #expect(DamageFormula.standard.damage(difficulty: difficulty, consecutiveMissedDays: 1)
                    == difficulty.missDamage)
        }
    }

    @Test("consecutive misses escalate, then stop at 2x")
    func escalationCaps() {
        let formula = DamageFormula.standard
        #expect(formula.escalation(forConsecutiveMissedDays: 1) == 1.0)
        #expect(formula.escalation(forConsecutiveMissedDays: 2) == 1.25)
        #expect(formula.escalation(forConsecutiveMissedDays: 5) == 2.0)
        #expect(formula.escalation(forConsecutiveMissedDays: 500) == 2.0)
    }

    @Test("missing is always cheaper than doing is worth, at every difficulty")
    func doingBeatsSkipping() {
        // An ambitious roadmap must never be a worse bet than a timid one: the worst-case
        // damage from an epic task stays below the XP it pays.
        for difficulty in TaskDifficulty.allCases {
            let worstDamage = DamageFormula.standard.damage(difficulty: difficulty,
                                                            consecutiveMissedDays: 99)
            #expect(worstDamage < difficulty.baseXP, "\(difficulty) punishes more than it rewards")
        }
    }

    @Test("the per-rollover cap is 40% of max HP and is at least 1")
    func capScalesWithMaxHP() {
        #expect(DamageFormula.standard.cap(forMaxHP: 50) == 20)
        #expect(DamageFormula.standard.cap(forMaxHP: 100) == 40)
        #expect(DamageFormula.standard.cap(forMaxHP: 1) == 1)
        #expect(DamageFormula.standard.cap(forMaxHP: 0) == 1)
    }

    @Test("capping clamps into 0...cap and never returns a negative")
    func cappingClamps() {
        let formula = DamageFormula.standard
        #expect(formula.capped(500, maxHP: 50) == 20)
        #expect(formula.capped(5, maxHP: 50) == 5)
        #expect(formula.capped(-5, maxHP: 50) == 0)
    }
}

@Suite("Game rules")
struct GameRulesTests {

    @Test("max HP starts at 50 and grows 5 per character level")
    func maxHPScales() {
        #expect(GameRules.standard.maxHP(forCharacterLevel: 1) == 50)
        #expect(GameRules.standard.maxHP(forCharacterLevel: 2) == 55)
        #expect(GameRules.standard.maxHP(forCharacterLevel: 11) == 100)
        // A level below 1 should not produce less than the base.
        #expect(GameRules.standard.maxHP(forCharacterLevel: 0) == 50)
    }

    @Test("healing and boss damage are always at least 1, so an effect is never invisible")
    func effectsAreNeverZero() {
        #expect(GameRules.standard.healAmount(forMaxHP: 1) >= 1)
        #expect(GameRules.standard.bossDamage(forXP: 1) >= 1)
        #expect(GameRules.standard.bossDamage(forXP: 20) == 10)
    }
}
