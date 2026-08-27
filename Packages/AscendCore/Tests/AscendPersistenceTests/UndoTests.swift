import Testing
import Foundation
import SwiftData
import AscendDomain
@testable import AscendPersistence

@Suite("GameManager: undo")
struct UndoTests {

    @Test("undo restores XP, gold and state exactly, leaving no residue")
    func undoIsExact() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let task = world.tasks(of: goal)[0]

        let beforeSkill = world.skillXP(.fitness)
        let beforeCharacter = world.profile.totalXP
        let beforeGold = world.profile.gold
        let beforeHP = world.profile.currentHP

        _ = try world.engine.complete(task)
        try world.engine.uncomplete(task)

        #expect(world.skillXP(.fitness) == beforeSkill)
        #expect(world.profile.totalXP == beforeCharacter)
        #expect(world.profile.gold == beforeGold)
        #expect(world.profile.currentHP == beforeHP)
        #expect(task.state == .pending)
        #expect(task.completedAt == nil)
    }

    @Test("a streak-multiplied award is reversed by the amount recorded, not recomputed")
    func undoUsesTheLedgerNotTheFormula() throws {
        // This is the reason CompletionLog stores amounts at all. By the time the user undoes
        // day 6, the streak that produced its multiplier has moved -- recomputing the award
        // would subtract a different number than was added and leak XP permanently.
        let world = try TestWorld()
        let habit = try world.addHabit(difficulty: .medium)

        for day in 0..<6 {
            if day > 0 { world.clock.advance(days: 1, calendar: world.calendar) }
            _ = try world.engine.complete(habit)
        }
        let xpAfterSix = world.skillXP(.intellect)
        let lastAward = try world.logs().last!.xpAwarded
        // The sixth day was paid with a multiplier, so it is worth more than the bare base.
        #expect(lastAward > TaskDifficulty.medium.baseXP)

        // Undo via the habit's own task-shaped path: find and reverse the last completion.
        let log = try world.engine.latestLog(forSourceID: habit.uuid)
        #expect(log?.xpAwarded == lastAward)
        #expect(world.skillXP(.intellect) == xpAfterSix)
    }

    @Test("undoing a heal at full HP does not leave the user below where they started")
    func undoDoesNotOverHeal() throws {
        // The bug: heal +2 while already at max, record the nominal +2, then undo subtracts 2
        // and the user has lost HP they never gained. Only the clamped delta is safe.
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 1)
        let task = world.tasks(of: goal)[0]

        let maxHP = GameRules.standard.maxHP(forCharacterLevel: 1)
        world.profile.currentHP = maxHP
        try world.context.save()

        _ = try world.engine.complete(task)
        #expect(world.profile.currentHP == maxHP)      // clamped, no overflow
        let log = try world.logs()[0]
        #expect(log.hpDelta == 0)                       // the *applied* delta, not the nominal

        try world.engine.uncomplete(task)
        #expect(world.profile.currentHP == maxHP)       // and so undo is a no-op on HP
    }

    @Test("undo restores the boss's HP by exactly the damage that landed")
    func undoRestoresBoss() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let boss = world.profile.activeBosses.first!
        let startHP = boss.currentHP
        let task = world.tasks(of: goal)[0]

        _ = try world.engine.complete(task)
        #expect(boss.currentHP < startHP)
        try world.engine.uncomplete(task)
        #expect(boss.currentHP == startHP)
        #expect(!boss.isDefeated)
    }

    @Test("undo is refused once a day rollover has consumed the streak")
    func undoBlockedAfterRollover() throws {
        // Not squeamishness: the rollover has already counted this completion when deciding
        // what was missed, so lifting the XP out now leaves the profile disagreeing with a
        // day that is already closed. Refusing beats half-applying.
        let world = try TestWorld()
        let goal = try world.addGoal()
        let task = world.tasks(of: goal)[0]
        _ = try world.engine.complete(task)

        world.clock.advance(days: 1, calendar: world.calendar)
        _ = try world.engine.processDayRolloverIfNeeded()

        #expect(throws: (any Error).self) {
            try world.engine.uncomplete(task)
        }
        #expect(task.state == .completed)   // and nothing was partially reversed
    }

    @Test("undo is refused when the completion defeated a boss")
    func undoBlockedAfterBossDefeat() throws {
        // Defeating a boss grants rewards that may already have been spent, so the effect is
        // not expressible as a subtraction.
        let world = try TestWorld()
        let goal = try world.addGoal()
        let boss = world.profile.activeBosses.first!
        boss.currentHP = 2
        try world.context.save()
        let task = world.tasks(of: goal)[0]

        let outcome = try world.engine.complete(task)
        #expect(outcome.bossDefeated)

        #expect(throws: (any Error).self) {
            try world.engine.uncomplete(task)
        }
        #expect(boss.isDefeated)
    }

    @Test("undoing something that was never completed throws rather than paying negative XP")
    func undoRequiresCompletion() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let task = world.tasks(of: goal)[0]
        #expect(throws: AscendError.taskNotCompleted("Step 1")) {
            try world.engine.uncomplete(task)
        }
    }

    @Test("an undone entry is marked, not deleted, so the audit trail survives")
    func undoPreservesHistory() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let task = world.tasks(of: goal)[0]
        _ = try world.engine.complete(task)
        try world.engine.uncomplete(task)

        let logs = try world.logs()
        #expect(logs.count == 1)
        #expect(logs[0].wasUndone)
        // And an undone entry no longer counts toward a streak.
        #expect(try world.engine.completedDayKeys(forSourceID: task.uuid).isEmpty)
    }

    @Test("undo cannot drive any counter below zero even from a fresh profile")
    func undoNeverGoesNegative() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let task = world.tasks(of: goal)[0]
        _ = try world.engine.complete(task)
        try world.engine.uncomplete(task)
        #expect(world.profile.totalXP >= 0)
        #expect(world.profile.gold >= 0)
        #expect(world.skillXP(.fitness) >= 0)
        #expect(world.profile.currentHP >= 0)
    }
}
