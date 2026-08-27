import Testing
import Foundation
import SwiftData
import AscendDomain
@testable import AscendPersistence

@Suite("Day rollover")
struct DayRolloverTests {

    @Test("nothing happens twice on the same day, however many times it is called")
    func rolloverIsIdempotent() throws {
        // The app-lifecycle events that call this genuinely do fire more than once.
        let world = try TestWorld()
        try world.addGoal()
        world.clock.advance(days: 1, calendar: world.calendar)

        let first = try world.engine.processDayRolloverIfNeeded()
        let hpAfterFirst = world.profile.currentHP
        #expect(first.count == 1)

        let second = try world.engine.processDayRolloverIfNeeded()
        #expect(second.isEmpty)
        #expect(world.profile.currentHP == hpAfterFirst)

        let third = try world.engine.processDayRolloverIfNeeded()
        #expect(third.isEmpty)
        #expect(world.profile.currentHP == hpAfterFirst)
    }

    @Test("no time passing means no rollover at all")
    func sameDayIsNoOp() throws {
        let world = try TestWorld()
        try world.addGoal()
        world.clock.advance(hours: 6, calendar: world.calendar)
        #expect(try world.engine.processDayRolloverIfNeeded().isEmpty)
        #expect(world.profile.currentHP == 50)
    }

    @Test("a missed daily step costs HP and is marked missed")
    func missedTaskCostsHP() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 1, difficulty: .medium)
        world.clock.advance(days: 1, calendar: world.calendar)

        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.count == 1)
        #expect(reports[0].missedCount == 1)
        #expect(reports[0].appliedDamage == TaskDifficulty.medium.missDamage)
        #expect(world.profile.currentHP == 50 - TaskDifficulty.medium.missDamage)
        #expect(world.tasks(of: goal)[0].state == .missed)
    }

    @Test("a step completed that day costs nothing")
    func completedTaskIsNotCharged() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 1)
        _ = try world.engine.complete(world.tasks(of: goal)[0])

        world.clock.advance(days: 1, calendar: world.calendar)
        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.allSatisfy { $0.missedCount == 0 })
        #expect(world.profile.currentHP >= 50)
    }

    @Test("a paused goal is never charged -- pausing is an offer, not a trap")
    func pausedGoalIsNotCharged() throws {
        let world = try TestWorld()
        try world.addGoal(taskCount: 3, status: .paused)
        world.clock.advance(days: 3, calendar: world.calendar)

        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.allSatisfy { $0.missedCount == 0 })
        #expect(world.profile.currentHP == 50)
    }

    @Test("weekly and one-shot steps are never charged for 'today'")
    func nonDailyIsNotCharged() throws {
        let world = try TestWorld()
        try world.addGoal(taskCount: 2, cadence: .weekly)
        try world.addGoal(taskCount: 2, cadence: .oneShot)
        world.clock.advance(days: 4, calendar: world.calendar)

        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.allSatisfy { $0.missedCount == 0 })
        #expect(world.profile.currentHP == 50)
    }

    // MARK: - The cap

    @Test("returning after two weeks away hurts but cannot one-shot the character")
    func damageIsCappedPerInvocation() throws {
        // The cap semantics that matter. At 40% of max HP *per game day*, five neglected days
        // resolve to 200% of max HP and kill any character outright -- the exact scenario the
        // cap exists to prevent. Capping the whole invocation is the correct reading, and this
        // is the test that pins it.
        let world = try TestWorld()
        try world.addGoal(taskCount: 5, difficulty: .epic)   // 10 damage each, 50/day raw
        world.clock.advance(days: 14, calendar: world.calendar)

        let reports = try world.engine.processDayRolloverIfNeeded()
        let totalApplied = reports.reduce(0) { $0 + $1.appliedDamage }
        let totalRaw = reports.reduce(0) { $0 + $1.rawDamage }
        let cap = GameRules.standard.damage.cap(forMaxHP: 50)

        #expect(totalRaw > cap * 5)              // the backlog really was enormous
        #expect(totalApplied == cap)             // and exactly one cap's worth landed
        #expect(world.profile.currentHP > 0)     // so the user is alive to see it
        #expect(reports.contains { $0.wasDamageCapped })
    }

    @Test("only a month of backlog is reconstructed, however long the user was away")
    func backlogIsBounded() throws {
        let world = try TestWorld()
        try world.addGoal(taskCount: 1)
        world.clock.advance(days: 400, calendar: world.calendar)

        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.count <= GameRules.standard.maxRolloverDaysProcessed)
        #expect(!reports.isEmpty)
    }

    @Test("three separate neglectful returns are needed to die, not one")
    func deathTakesRepeatedNeglect() throws {
        let world = try TestWorld()
        try world.addGoal(taskCount: 5, difficulty: .epic)

        var defeats = 0
        for _ in 0..<3 {
            world.clock.advance(days: 5, calendar: world.calendar)
            let reports = try world.engine.processDayRolloverIfNeeded()
            if reports.contains(where: \.wasDefeated) { defeats += 1 }
        }
        #expect(defeats >= 1)
        #expect(world.profile.defeatCount >= 1)
    }

    // MARK: - Defeat

    @Test("defeat costs progress toward the next level, never the level itself")
    func defeatIsBoundedAndNeverDemotes() throws {
        // A bounded, explicable loss. Demoting a level instead would cost one user 1 XP and
        // another 574 for the same mistake, which reads as a bug however correct it is -- and
        // it would let "reached level 10" un-fire.
        let world = try TestWorld()
        try world.addGoal(taskCount: 6, difficulty: .epic)
        world.profile.totalXP = ProgressionCurve.character.totalXP(toReach: 5) + 400
        world.profile.currentHP = 3
        try world.context.save()

        let levelBefore = ProgressionCurve.character.level(forTotalXP: world.profile.totalXP)
        world.clock.advance(days: 3, calendar: world.calendar)
        _ = try world.engine.processDayRolloverIfNeeded()

        let levelAfter = ProgressionCurve.character.level(forTotalXP: world.profile.totalXP)
        #expect(world.profile.defeatCount == 1)
        #expect(levelAfter == levelBefore)                                        // no demotion
        #expect(world.profile.totalXP == ProgressionCurve.character.totalXP(toReach: levelBefore))
        #expect(world.profile.currentHP > 0)                                      // revived
        #expect(world.profile.gold == 0)
    }

    @Test("a defeat happens at most once per rollover, not once per queued day")
    func oneDefeatPerRollover() throws {
        // Defeat restores HP, so without the break the rest of the backlog would land on a
        // full bar and could kill the same character twice in one call.
        let world = try TestWorld()
        try world.addGoal(taskCount: 6, difficulty: .epic)
        world.profile.currentHP = 2
        try world.context.save()

        world.clock.advance(days: 20, calendar: world.calendar)
        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.filter(\.wasDefeated).count <= 1)
        #expect(world.profile.defeatCount <= 1)
    }

    // MARK: - Hostile clocks

    @Test("winding the device clock backwards is not a windfall and not a crash")
    func backwardsClockIsSafe() throws {
        let world = try TestWorld()
        try world.addGoal(taskCount: 2)
        let hpBefore = world.profile.currentHP

        world.clock.advance(days: -10, calendar: world.calendar)
        let reports = try world.engine.processDayRolloverIfNeeded()

        #expect(reports.isEmpty)
        #expect(world.profile.currentHP == hpBefore)
        // The marker is reset to now, so the days are not re-charged on the way back either.
        #expect(world.profile.lastRolloverDate == world.clock.now)
    }

    @Test("a broken habit streak is reported and the cache is repaired")
    func brokenStreakIsReported() throws {
        let world = try TestWorld()
        let habit = try world.addHabit()
        for day in 0..<3 {
            if day > 0 { world.clock.advance(days: 1, calendar: world.calendar) }
            _ = try world.engine.complete(habit)
        }
        #expect(habit.currentStreak == 3)

        // Two days away.
        world.clock.advance(days: 3, calendar: world.calendar)
        let reports = try world.engine.processDayRolloverIfNeeded()

        #expect(reports.contains { !$0.brokenStreakTitles.isEmpty })
        #expect(habit.currentStreak == 0)
        // The best streak is a high-water mark and survives.
        #expect(habit.bestStreak == 3)
        let recomputed = try world.engine.streak(forHabit: habit)
        #expect(habit.currentStreak == recomputed)
    }

    @Test("escalation makes the fifth consecutive miss cost more than the first")
    func escalationApplies() throws {
        let world = try TestWorld()
        try world.addGoal(taskCount: 1, difficulty: .easy)
        world.clock.advance(days: 5, calendar: world.calendar)

        let reports = try world.engine.processDayRolloverIfNeeded()
        #expect(reports.count == 5)
        #expect(reports.last!.rawDamage > reports.first!.rawDamage)
    }
}

@Suite("Seeding")
struct SeedTests {

    @Test("seeding twice yields one profile, not two silently diverging characters")
    func seedingIsIdempotent() throws {
        let world = try TestWorld()
        let again = try DefaultSeed.profile(in: world.context)
        let all = try world.context.fetch(FetchDescriptor<UserProfile>())
        #expect(all.count == 1)
        #expect(again.id == world.profile.id)
    }

    @Test("a fresh profile has one skill tree per domain and a starting boss")
    func seedShape() throws {
        let world = try TestWorld()
        #expect(world.profile.skills.count == SkillDomain.allCases.count)
        for domain in SkillDomain.allCases {
            #expect(world.profile.skillTree(for: domain) != nil)
        }
        #expect(world.profile.activeBosses.count == 1)
        #expect(world.profile.currentHP == 50)
        #expect(world.profile.totalXP == 0)
    }

    @Test("a profile missing a skill tree gets it backfilled rather than staying broken")
    func backfillsMissingTrees() throws {
        // The upgrade path: adding a SkillDomain case in a later release must not leave
        // existing installs permanently without that skill.
        let world = try TestWorld()
        let doomed = world.profile.skillTree(for: .wealth)!
        world.context.delete(doomed)
        try world.context.save()
        #expect(world.profile.skills.count == SkillDomain.allCases.count - 1)

        _ = try DefaultSeed.profile(in: world.context)
        #expect(world.profile.skills.count == SkillDomain.allCases.count)
        #expect(world.profile.skillTree(for: .wealth) != nil)
    }
}

@Suite("Roadmap import")
struct RoadmapImportTests {

    @Test("imported milestones and tasks keep the order the plan was generated in")
    func orderIsPreserved() throws {
        // SwiftData relationship arrays are unordered, so this is the test that catches a
        // roadmap silently shuffling into nonsense after a relaunch.
        let world = try TestWorld()
        let draft = RoadmapDraft(
            title: "Learn SwiftUI",
            summary: "",
            primaryDomain: .intellect,
            milestones: (0..<5).map { index in
                MilestoneDraft(title: "Tier \(index)", detail: "", orderIndex: index,
                               tasks: (0..<3).map { taskIndex in
                                   TaskDraft(title: "T\(index)-\(taskIndex)", detail: "",
                                             difficulty: .easy, cadence: .daily,
                                             domain: .intellect, orderIndex: taskIndex)
                               })
            })
        let goal = try RoadmapImporter.importDraft(
            draft,
            request: RoadmapRequest(goalText: "Learn SwiftUI"),
            generatorIdentifier: "test/fixture",
            into: world.profile,
            context: world.context,
            now: world.clock.now,
            calendar: world.calendar)

        #expect(goal.orderedMilestones.map(\.title) == ["Tier 0", "Tier 1", "Tier 2", "Tier 3", "Tier 4"])
        #expect(goal.orderedMilestones[2].orderedTasks.map(\.title) == ["T2-0", "T2-1", "T2-2"])
        #expect(goal.generatorIdentifier == "test/fixture")
    }

    @Test("only the first milestone starts unlocked, so a plan is not dumped on the user at once")
    func firstMilestoneIsActive() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        #expect(goal.orderedMilestones[0].status == .active)
        #expect(goal.status == .active)
    }

    @Test("a recalibration side-quest sorts ahead of the remaining plan")
    func sideQuestComesFirst() throws {
        let world = try TestWorld()
        let goal = try world.addGoal()
        let patch = RoadmapPatch(
            rationale: "You can pick this back up.",
            sideQuest: MilestoneDraft(title: "Back on the path", detail: "", orderIndex: 0,
                                      tasks: [TaskDraft(title: "One small step", detail: "",
                                                        difficulty: .trivial, cadence: .oneShot,
                                                        domain: .discipline, orderIndex: 0)]))
        let quest = try RoadmapImporter.importPatch(patch, into: goal,
                                                    context: world.context, now: world.clock.now)
        #expect(quest != nil)
        #expect(goal.orderedMilestones.first?.title == "Back on the path")
        #expect(goal.orderedMilestones.first?.isSideQuest == true)
    }
}
