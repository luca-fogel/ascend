import Testing
import Foundation
import SwiftData
import AscendDomain
@testable import AscendPersistence

@Suite("Milestone unlocking and lazy step generation")
struct MilestoneUnlockTests {

    /// A three-tier goal with steps only in the first tier -- the shape lazy stage-two
    /// generation actually produces.
    static func lazyGoal(in world: TestWorld) throws -> Goal {
        let draft = RoadmapDraft(
            title: "Learn SwiftUI",
            summary: "",
            primaryDomain: .intellect,
            milestones: (0..<3).map { index in
                MilestoneDraft(
                    title: "Tier \(index)", detail: "", orderIndex: index,
                    tasks: index == 0
                        ? [TaskDraft(title: "Step A", detail: "", difficulty: .easy,
                                     cadence: .daily, domain: .intellect, orderIndex: 0)]
                        : [])
            })
        return try RoadmapImporter.importDraft(
            draft,
            request: RoadmapRequest(goalText: "Learn SwiftUI"),
            generatorIdentifier: "test/fixture",
            into: world.profile,
            context: world.context,
            now: world.clock.now,
            calendar: world.calendar)
    }

    @Test("only the first tier starts unlocked")
    func onlyFirstTierIsOpen() throws {
        let world = try TestWorld()
        let goal = try Self.lazyGoal(in: world)
        #expect(goal.orderedMilestones.map(\.status) == [.active, .locked, .locked])
    }

    @Test("finishing a tier opens the next one and says so in the outcome")
    func finishingATierUnlocksTheNext() throws {
        // Without this the roadmap dead-ends after tier one, because the importer deliberately
        // locks everything past the first.
        let world = try TestWorld()
        let goal = try Self.lazyGoal(in: world)
        let task = goal.orderedMilestones[0].orderedTasks[0]

        let outcome = try world.engine.complete(task)

        #expect(outcome.unlockedMilestoneTitle == "Tier 1")
        #expect(goal.orderedMilestones.map(\.status) == [.completed, .active, .locked])
    }

    @Test("a completion that does not finish its tier unlocks nothing")
    func partialTierUnlocksNothing() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 3)
        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.unlockedMilestoneTitle == nil)
    }

    @Test("the last tier unlocks nothing and does not crash looking for a successor")
    func lastTierIsTerminal() throws {
        let world = try TestWorld()
        let goal = try world.addGoal(taskCount: 1)
        let outcome = try world.engine.complete(world.tasks(of: goal)[0])
        #expect(outcome.unlockedMilestoneTitle == nil)
        #expect(goal.orderedMilestones[0].status == .completed)
    }

    @Test("steps can be filled into a tier after the goal was created")
    func lazyImportFillsATier() throws {
        let world = try TestWorld()
        let goal = try Self.lazyGoal(in: world)
        let tier1 = goal.orderedMilestones[1]
        #expect(tier1.tasks.isEmpty)

        let drafts = (0..<4).map { index in
            TaskDraft(title: "Late step \(index)", detail: "", difficulty: .medium,
                      cadence: .daily, domain: .intellect, orderIndex: index)
        }
        let created = try RoadmapImporter.importTasks(drafts, into: tier1,
                                                      context: world.context, now: world.clock.now)
        #expect(created.count == 4)
        #expect(tier1.orderedTasks.map(\.title) == ["Late step 0", "Late step 1", "Late step 2", "Late step 3"])
        #expect(tier1.orderedTasks.map(\.orderIndex) == [0, 1, 2, 3])
    }

    @Test("filling a tier twice does not duplicate its steps")
    func lazyImportIsIdempotent() throws {
        // A double-tap or a retried request after a slow on-device call must not produce two
        // copies of a tier's work.
        let world = try TestWorld()
        let goal = try Self.lazyGoal(in: world)
        let tier1 = goal.orderedMilestones[1]
        let drafts = [TaskDraft(title: "Only once", detail: "", difficulty: .easy,
                                cadence: .daily, domain: .intellect, orderIndex: 0)]

        _ = try RoadmapImporter.importTasks(drafts, into: tier1, context: world.context)
        _ = try RoadmapImporter.importTasks(drafts, into: tier1, context: world.context)
        _ = try RoadmapImporter.importTasks(drafts, into: tier1, context: world.context)

        #expect(tier1.tasks.count == 1)
    }

    @Test("a whole three-tier goal can be walked end to end, unlocking as it goes")
    func walkTheWholeRoadmap() throws {
        let world = try TestWorld()
        let goal = try Self.lazyGoal(in: world)

        // Tier 0 -> unlocks tier 1.
        _ = try world.engine.complete(goal.orderedMilestones[0].orderedTasks[0])

        // Tier 1's steps arrive lazily, the way the real flow generates them.
        let tier1 = goal.orderedMilestones[1]
        _ = try RoadmapImporter.importTasks(
            [TaskDraft(title: "T1 step", detail: "", difficulty: .easy,
                       cadence: .daily, domain: .intellect, orderIndex: 0)],
            into: tier1, context: world.context, now: world.clock.now)

        world.clock.advance(days: 1, calendar: world.calendar)
        let second = try world.engine.complete(tier1.orderedTasks[0])
        #expect(second.unlockedMilestoneTitle == "Tier 2")
        #expect(goal.orderedMilestones.map(\.status) == [.completed, .completed, .active])
    }

    @Test("undoing the completion that opened a tier re-closes the tier it finished")
    func undoReclosesTheTier() throws {
        let world = try TestWorld()
        let goal = try Self.lazyGoal(in: world)
        let task = goal.orderedMilestones[0].orderedTasks[0]
        _ = try world.engine.complete(task)
        #expect(goal.orderedMilestones[0].status == .completed)

        try world.engine.uncomplete(task)
        #expect(goal.orderedMilestones[0].status == .active)
    }
}
