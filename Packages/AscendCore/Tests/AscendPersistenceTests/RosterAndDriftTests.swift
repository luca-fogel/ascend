import Testing
import Foundation
import SwiftData
import AscendDomain
@testable import AscendPersistence

@Suite("Roster: habits and bosses")
struct RosterTests {

    @Test("a habit can be created and is attached to the profile")
    func addHabit() throws {
        let world = try TestWorld()
        let habit = try Roster.addHabit(title: "Read for 20 minutes", difficulty: .easy,
                                        cadence: .daily, domain: .intellect,
                                        to: world.profile, context: world.context,
                                        now: world.clock.now)
        #expect(world.profile.habits.count == 1)
        #expect(habit.profile?.uuid == world.profile.uuid)
        #expect(habit.isActive)
    }

    @Test("a duplicate habit title returns the existing one rather than charging twice a day")
    func duplicateHabitsAreRejected() throws {
        // Two habits with one intention means two lots of miss damage every rollover.
        let world = try TestWorld()
        let first = try Roster.addHabit(title: "Read", difficulty: .easy, cadence: .daily,
                                        domain: .intellect, to: world.profile, context: world.context)
        let second = try Roster.addHabit(title: "  read  ", difficulty: .hard, cadence: .weekly,
                                         domain: .fitness, to: world.profile, context: world.context)
        #expect(world.profile.habits.count == 1)
        #expect(first.uuid == second.uuid)
        // And the original is not silently mutated by the second attempt.
        #expect(first.difficulty == .easy)
    }

    @Test("a blank habit name is refused")
    func blankHabitRefused() throws {
        let world = try TestWorld()
        #expect(throws: (any Error).self) {
            _ = try Roster.addHabit(title: "   ", difficulty: .easy, cadence: .daily,
                                    domain: .intellect, to: world.profile, context: world.context)
        }
    }

    @Test("retiring keeps the record and stops the habit costing HP")
    func retireIsNonDestructive() throws {
        let world = try TestWorld()
        let habit = try world.addHabit()
        for day in 0..<3 {
            if day > 0 { world.clock.advance(days: 1, calendar: world.calendar) }
            _ = try world.engine.complete(habit)
        }
        #expect(habit.bestStreak == 3)

        try Roster.retire(habit, context: world.context)
        #expect(!habit.isActive)
        #expect(habit.bestStreak == 3)          // history survives
        #expect(!habit.accruesMissDamage)       // and it stops being charged for

        // A rollover after retiring must not charge for it.
        world.clock.advance(days: 3, calendar: world.calendar)
        let hpBefore = world.profile.currentHP
        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.allSatisfy { $0.missedCount == 0 })
        #expect(world.profile.currentHP >= hpBefore)
    }

    @Test("a boss can be summoned once, and summoning the same kind twice is a no-op")
    func summonBoss() throws {
        let world = try TestWorld()
        let first = try Roster.summonBoss(.doubt, for: world.profile, context: world.context)
        let second = try Roster.summonBoss(.doubt, for: world.profile, context: world.context)
        #expect(first.uuid == second.uuid)
        #expect(world.profile.bosses.filter { $0.kindRaw == BossKind.doubt.rawValue }.count == 1)
    }

    @Test("available kinds exclude the ones already in play")
    func availableKindsShrink() throws {
        let world = try TestWorld()
        // Procrastination is seeded, so it should already be excluded.
        let initial = Roster.availableBossKinds(for: world.profile)
        #expect(!initial.contains(.procrastination))
        #expect(initial.count == BossKind.allCases.count - 1)

        _ = try Roster.summonBoss(.burnout, for: world.profile, context: world.context)
        #expect(!Roster.availableBossKinds(for: world.profile).contains(.burnout))
    }
}

@Suite("Recalibration advisor")
struct RecalibrationAdvisorTests {

    @Test("a goal being worked on is not flagged as drifting")
    func activeGoalIsFine() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2)
        _ = try world.engine.complete(world.tasks(of: goal)[0])

        let days = try RecalibrationAdvisor.missedDays(
            for: goal, profile: world.profile, context: world.context,
            streaks: world.streaks, now: world.clock.now)
        #expect(days == nil)
    }

    @Test("one or two quiet days is not enough to offer a rewrite")
    func shortGapIsNotFlagged() throws {
        // Offering to rewrite someone's plan the first time they skip a day is both annoying
        // and patronising, so the threshold is deliberately above that.
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2)
        _ = try world.engine.complete(world.tasks(of: goal)[0])
        world.clock.advance(days: 2, calendar: world.calendar)

        let days = try RecalibrationAdvisor.missedDays(
            for: goal, profile: world.profile, context: world.context,
            streaks: world.streaks, now: world.clock.now)
        #expect(days == nil)
    }

    @Test("three or more days of silence flags the goal, with the count")
    func longGapIsFlagged() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2)
        _ = try world.engine.complete(world.tasks(of: goal)[0])
        world.clock.advance(days: 5, calendar: world.calendar)

        let days = try RecalibrationAdvisor.missedDays(
            for: goal, profile: world.profile, context: world.context,
            streaks: world.streaks, now: world.clock.now)
        #expect(days == 5)
    }

    @Test("a goal never started at all is noticed, counting from its creation")
    func neverStartedIsFlagged() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2)
        world.clock.advance(days: 4, calendar: world.calendar)

        let days = try RecalibrationAdvisor.missedDays(
            for: goal, profile: world.profile, context: world.context,
            streaks: world.streaks, now: world.clock.now)
        #expect(days == 4)
    }

    @Test("a paused goal is never flagged -- pausing is a choice, not drift")
    func pausedGoalIsExempt() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 2, status: .paused)
        world.clock.advance(days: 10, calendar: world.calendar)

        let days = try RecalibrationAdvisor.missedDays(
            for: goal, profile: world.profile, context: world.context,
            streaks: world.streaks, now: world.clock.now)
        #expect(days == nil)
    }

    @Test("the worst-drifting goal is the one offered a way back")
    func worstGoalIsChosen() throws {
        let world = try TestWorld()
        let old = try world.addGoal(taskCount: 1, domain: .fitness)
        world.clock.advance(days: 6, calendar: world.calendar)
        let recent = try world.addGoal(taskCount: 1, domain: .intellect)
        world.clock.advance(days: 3, calendar: world.calendar)

        let found = try RecalibrationAdvisor.goalNeedingRecalibration(
            profile: world.profile, context: world.context,
            streaks: world.streaks, now: world.clock.now)
        let picked = try #require(found)
        #expect(picked.goal.uuid == old.uuid)
        #expect(picked.missedDays > 3)
        #expect(recent.uuid != picked.goal.uuid)
    }

    @Test("the request carries only the milestones still ahead")
    func requestExcludesFinishedTiers() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 1)
        _ = try world.engine.complete(world.tasks(of: goal)[0])

        let request = RecalibrationAdvisor.request(for: goal, missedDays: 4)
        #expect(request.missedDays == 4)
        #expect(request.minutesPerDay == goal.minutesPerDay)
        #expect(!request.remainingMilestoneTitles.contains("Foundations"))
    }
}
