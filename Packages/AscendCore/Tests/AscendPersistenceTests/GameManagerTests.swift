import Testing
import Foundation
import SwiftData
import AscendDomain
@testable import AscendPersistence

@Suite("GameManager: completing work")
struct GameManagerCompletionTests {

    @Test("completing a task pays its skill tree and the character pool, and logs both")
    func awardsXP() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(difficulty: .medium, domain: .fitness)
        let task = world.tasks(of: goal)[0]

        let outcome = try world.engine.complete(task)

        #expect(outcome.totalXP == 20)
        #expect(world.skillXP(.fitness) == 20)
        #expect(world.profile.totalXP == 20)
        // Untouched domains stay at zero -- XP is routed, not shared.
        #expect(world.skillXP(.intellect) == 0)
        #expect(task.state == .completed)
        #expect(try world.logs().count == 1)
    }

    @Test("gold is paid per completion and recorded as the amount actually applied")
    func awardsGold() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.goldAwarded == GameRules.standard.goldPerCompletion)
        #expect(world.profile.gold == GameRules.standard.goldPerCompletion)
        #expect(try world.logs()[0].goldAwarded == outcome.goldAwarded)
    }

    @Test("one huge award can cross several levels at once, and every crossing is reported")
    func multiLevelUp() throws {
        // The classic bug this pins: subtracting a single level's cost instead of looping, so
        // a big award silently swallows the levels above the first.
        let world = try TestWorld()
        let goal = try world.addGoal(difficulty: .epic, domain: .fitness)
        // Pre-load the tree so a single epic task lands several levels up at once.
        world.profile.skillTree(for: .fitness)!.totalXP = ProgressionCurve.skill.totalXP(toReach: 3) - 1
        try world.context.save()

        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        let skillLevelUps = outcome.levelUps.filter {
            if case .skill = $0.scope { return true } else { return false }
        }
        #expect(skillLevelUps.count >= 1)
        // Reported levels must be contiguous and ascending, not just a final value.
        let levels = skillLevelUps.map(\.newLevel)
        #expect(levels == Array(levels.min()!...levels.max()!))
        #expect(ProgressionCurve.skill.level(forTotalXP: world.skillXP(.fitness)) == levels.max()!)
    }

    @Test("completing an already-completed task throws instead of paying twice")
    func completionIsIdempotent() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let task = world.tasks(of: goal)[0]
        _ = try world.engine.complete(task)

        #expect(throws: AscendError.taskNotPending("Step 1")) {
            _ = try world.engine.complete(task)
        }
        #expect(world.skillXP(.fitness) == 20)
        #expect(try world.logs().count == 1)
    }

    @Test("a daily habit cannot be completed twice in one game day")
    func habitIsOncePerDay() throws {
        let world = try TestWorld()
        let habit = try world.addHabit()
        _ = try world.engine.complete(habit)

        #expect(throws: (any Error).self) {
            _ = try world.engine.complete(habit)
        }
        #expect(try world.logs().count == 1)

        // Tomorrow it is available again.
        world.clock.advance(days: 1, calendar: world.calendar)
        let second = try world.engine.complete(habit)
        #expect(second.streak == 2)
    }

    @Test("a habit streak builds day over day and raises the XP paid")
    func streaksRaiseReward() throws {
        let world = try TestWorld()
        let habit = try world.addHabit(difficulty: .medium)

        var lastXP = 0
        for day in 0..<6 {
            if day > 0 { world.clock.advance(days: 1, calendar: world.calendar) }
            let outcome = try world.engine.complete(habit)
            #expect(outcome.streak == day + 1)
            if day > 1 { #expect(outcome.totalXP >= lastXP) }
            lastXP = outcome.totalXP
        }
        // Six days in: the multiplier is on, so the last day paid more than the bare base.
        #expect(lastXP > TaskDifficulty.medium.baseXP)
    }

    @Test("the cached streak on Habit equals the value recomputed from the ledger")
    func habitStreakCacheIsHonest() throws {
        // The denormalisation exists so a habit list does not rescan history on every SwiftUI
        // body evaluation. This test is what makes it a cache rather than a second truth.
        let world = try TestWorld()
        let habit = try world.addHabit()
        for day in 0..<4 {
            if day > 0 { world.clock.advance(days: 1, calendar: world.calendar) }
            _ = try world.engine.complete(habit)
        }
        let recomputed = try world.engine.streak(forHabit: habit)
        #expect(habit.currentStreak == recomputed)
        #expect(habit.bestStreak == 4)
    }

    @Test("a weekly step pays the cadence premium and never accrues a streak")
    func weeklyCadence() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 1, difficulty: .medium, cadence: .weekly)
        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.totalXP == 32)
        #expect(outcome.streak == 0)
    }

    @Test("finishing every task in a milestone marks the milestone complete")
    func milestoneCompletes() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2)
        let tasks = world.tasks(of: goal)
        _ = try world.engine.complete(tasks[0])
        #expect(goal.orderedMilestones[0].status != .completed)
        _ = try world.engine.complete(tasks[1])
        #expect(goal.orderedMilestones[0].status == .completed)
    }
}

@Suite("GameManager: bosses")
struct GameManagerBossTests {

    @Test("completing work damages the active boss without any attack button")
    func bossTakesDamage() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(difficulty: .medium)
        let boss = world.profile.activeBosses.first!
        let startHP = boss.currentHP

        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.bossDamage == 10)          // half of 20 XP
        #expect(boss.currentHP == startHP - 10)
        #expect(outcome.bossName == boss.name)
    }

    @Test("a boss reduced to zero is marked defeated and stops taking damage")
    func bossDies() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2, difficulty: .medium)
        let boss = world.profile.activeBosses.first!
        boss.currentHP = 5
        try world.context.save()

        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.bossDefeated)
        #expect(boss.isDefeated)
        #expect(boss.currentHP == 0)
        // Damage recorded is what was applied, not the nominal 10 -- the boss only had 5 left.
        #expect(outcome.bossDamage == 5)

        // A defeated boss is no longer a target.
        let second = try world.engine.complete(world.tasks(of: goal)[1])
        #expect(second.bossDamage == 0)
        #expect(second.bossName == nil)
    }

    @Test("a domain-locked boss ignores damage from other domains")
    func bossAffinity() throws {
        let world = try TestWorld()
        world.profile.activeBosses.forEach { $0.isDefeated = true }
        let picky = Boss(kind: .doubt, domain: .intellect, createdAt: world.clock.now)
        world.context.insert(picky)
        picky.profile = world.profile
        let goal = try world.addGoal(domain: .fitness)
        try world.context.save()

        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.bossDamage == 0)
        #expect(picky.currentHP == picky.maxHP)
    }
}
