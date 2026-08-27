import Testing
import Foundation
@testable import AscendDomain

@Suite("Progression curve")
struct ProgressionCurveTests {

    /// The regression tripwire. These are not magic numbers to be updated when they fail --
    /// a failure here means the cost of every level changed, which silently re-levels every
    /// existing save file. Changing them should be a deliberate, reviewed diff.
    @Test("the cost of levels 1-20 is pinned, so rebalancing can never be an accident")
    func skillCurveIsPinned() {
        let expected = [100, 228, 370, 524, 686, 856, 1033, 1216, 1404, 1597,
                        1795, 1997, 2204, 2414, 2628, 2846, 3066, 3290, 3518, 3748]
        let actual = (1...20).map { ProgressionCurve.skill.xpForNextLevel(after: $0) }
        #expect(actual == expected)
    }

    @Test("the character curve is pinned too, and is steeper than the skill curve at every level")
    func characterCurveIsPinnedAndSteeper() {
        let expected = [340, 801, 1329, 1910, 2532, 3191, 3883, 4604, 5352, 6125,
                        6921, 7740, 8579, 9437, 10314, 11209, 12122, 13050, 13995, 14955]
        let actual = (1...20).map { ProgressionCurve.character.xpForNextLevel(after: $0) }
        #expect(actual == expected)

        // The character pool receives XP from all six domains at once, so if it were not
        // steeper the headline level would race ahead of every skill behind it.
        for level in 1...20 {
            #expect(ProgressionCurve.character.xpForNextLevel(after: level)
                    > ProgressionCurve.skill.xpForNextLevel(after: level))
        }
    }

    @Test("cost never decreases, so the binary search in level(forTotalXP:) is valid")
    func costIsMonotonic() {
        for curve in [ProgressionCurve.skill, .character] {
            var previous = 0
            for level in 1..<ProgressionCurve.maxLevel {
                let cost = curve.xpForNextLevel(after: level)
                #expect(cost >= previous, "cost fell at level \(level)")
                previous = cost
            }
        }
    }

    @Test("cost is always at least 1 -- a zero would make the level-up loop non-terminating")
    func costIsNeverZero() {
        // Deliberately absurd parameters: the clamp is a structural guarantee, not a
        // consequence of the tuned presets happening to be positive.
        let degenerate = ProgressionCurve(base: 0, exponent: 0, linear: 0)
        for level in 1...50 {
            #expect(degenerate.xpForNextLevel(after: level) >= 1)
        }
    }

    @Test("total XP to reach a level is the running sum of the costs below it")
    func cumulativeMatchesSum() {
        for curve in [ProgressionCurve.skill, .character] {
            #expect(curve.totalXP(toReach: 1) == 0)
            var running = 0
            for level in 1...60 {
                running += curve.xpForNextLevel(after: level)
                #expect(curve.totalXP(toReach: level + 1) == running, "diverged at level \(level)")
            }
        }
    }

    @Test("level and total XP round-trip exactly at every threshold and either side of it")
    func levelRoundTripsAtBoundaries() {
        let curve = ProgressionCurve.skill
        for level in 1...80 {
            let floorXP = curve.totalXP(toReach: level)
            #expect(curve.level(forTotalXP: floorXP) == level, "at the threshold for \(level)")
            if level > 1 {
                // One XP short must still be the previous level -- the classic off-by-one in
                // a hand-rolled binary search.
                #expect(curve.level(forTotalXP: floorXP - 1) == level - 1, "one below \(level)")
            }
            #expect(curve.level(forTotalXP: floorXP + 1) == level, "one above \(level)")
        }
    }

    @Test("zero and negative XP are level 1, not a crash or level 0")
    func degenerateXPIsLevelOne() {
        #expect(ProgressionCurve.skill.level(forTotalXP: 0) == 1)
        #expect(ProgressionCurve.skill.level(forTotalXP: -500) == 1)
        #expect(ProgressionCurve.skill.progress(forTotalXP: -500).level == 1)
    }

    @Test("absurd XP saturates at maxLevel instead of running off the end of the table")
    func absurdXPSaturates() {
        #expect(ProgressionCurve.skill.level(forTotalXP: Int.max) == ProgressionCurve.maxLevel)
        #expect(ProgressionCurve.character.level(forTotalXP: Int.max) == ProgressionCurve.maxLevel)
    }

    @Test("progress splits total XP into a level plus the remainder inside it")
    func progressDecomposesXP() {
        let curve = ProgressionCurve.skill
        let xp = curve.totalXP(toReach: 7) + 300
        let progress = curve.progress(forTotalXP: xp)
        #expect(progress.level == 7)
        #expect(progress.xpIntoLevel == 300)
        #expect(progress.xpForNextLevel == curve.xpForNextLevel(after: 7))
        #expect(progress.xpRemaining == curve.xpForNextLevel(after: 7) - 300)
    }

    @Test("the fraction a ring draws is always between 0 and 1 and never NaN")
    func fractionIsAlwaysDrawable() {
        for xp in [0, 1, 99, 100, 5_000, 1_000_000, Int.max] {
            let fraction = ProgressionCurve.skill.progress(forTotalXP: xp).fraction
            #expect(!fraction.isNaN)
            #expect(fraction >= 0 && fraction <= 1, "out of range at \(xp)")
        }
        // The explicit divide-by-zero guard, reached only at maxLevel where cost is Int.max.
        #expect(LevelProgress(level: 1, xpIntoLevel: 5, xpForNextLevel: 0).fraction == 1)
    }

    @Test("level 2 is reachable in about five medium tasks -- the shape onboarding depends on")
    func earlyProgressionIsFast() {
        let fiveMediumTasks = 5 * TaskDifficulty.medium.baseXP  // 100
        #expect(ProgressionCurve.skill.level(forTotalXP: fiveMediumTasks) == 2)
    }
}
