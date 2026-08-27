import Testing
import Foundation
import AscendDomain
@testable import AscendIntelligence

@Suite("Template roadmap service")
struct TemplateRoadmapServiceTests {

    /// Zero latency in tests. The default simulated delay exists so loading states stay
    /// reachable in previews; making the suite wait for it would buy nothing.
    static let service = TemplateRoadmapService(simulatedLatency: .zero)

    @Test("the fallback provider is always usable -- that is the whole point of it")
    func alwaysAvailable() {
        #expect(Self.service.isConfigured)
        #expect(Self.service.unavailableReason == nil)
        #expect(Self.service.identifier == "template/v1")
    }

    @Test("it produces a plan that already satisfies the validator")
    func producesValidPlan() async throws {
        let request = RoadmapRequest(goalText: "Get into Equinox shape",
                                     horizonWeeks: 8,
                                     minutesPerDay: 45,
                                     preferredDomains: [.fitness])
        let draft = try await Self.service.milestonePlan(for: request)
        // Round-tripping through the validator must be a no-op: a provider that emits output
        // its own validator would reject is a provider that fails in production only.
        #expect(try RoadmapValidator.validated(draft) == draft)
        #expect(draft.primaryDomain == .fitness)
        #expect(!draft.milestones.isEmpty)
    }

    @Test("a short horizon gets fewer, larger tiers instead of a padded plan")
    func horizonShapesTierCount() async throws {
        let short = try await Self.service.milestonePlan(
            for: RoadmapRequest(goalText: "Run a 5k", horizonWeeks: 2))
        let medium = try await Self.service.milestonePlan(
            for: RoadmapRequest(goalText: "Run a 5k", horizonWeeks: 6))
        let long = try await Self.service.milestonePlan(
            for: RoadmapRequest(goalText: "Run a 5k", horizonWeeks: 16))

        #expect(short.milestones.count < medium.milestones.count)
        #expect(medium.milestones.count < long.milestones.count)
    }

    @Test("the generated steps cover a mix of cadences, not just dailies")
    func tasksCoverCadences() async throws {
        let request = RoadmapRequest(goalText: "Learn SwiftUI properly", horizonWeeks: 8)
        let draft = try await Self.service.milestonePlan(for: request)
        let tasks = try await Self.service.tasks(for: draft.milestones[0], in: request)

        #expect(tasks.count >= 3)
        #expect(Set(tasks.map(\.cadence)).count > 1)
        #expect(try RoadmapValidator.validatedTasks(tasks, milestoneTitle: "x") == tasks)
    }

    @Test("fullRoadmap runs both stages and fills every milestone")
    func fullRoadmapFillsTasks() async throws {
        let request = RoadmapRequest(goalText: "Write a novel this year", horizonWeeks: 12)
        let draft = try await Self.service.fullRoadmap(for: request)
        #expect(!draft.milestones.isEmpty)
        for milestone in draft.milestones {
            #expect(!milestone.tasks.isEmpty, "\(milestone.title) had no steps")
        }
    }

    @Test("recalibration returns a side-quest that is easier than the plan it rejoins")
    func recalibrationIsGentle() async throws {
        let patch = try await Self.service.recalibrate(
            RecalibrationRequest(goalTitle: "Run a 5k",
                                 goalSummary: "Finish a parkrun",
                                 missedDays: 5,
                                 remainingMilestoneTitles: ["Build the habit", "Raise the distance"],
                                 minutesPerDay: 30))
        let quest = try #require(patch.sideQuest)
        #expect(!patch.rationale.isEmpty)
        #expect(!quest.tasks.isEmpty)
        // "Easier" is the actual requirement, so it is the actual assertion.
        #expect(quest.tasks.allSatisfy { $0.difficulty == .trivial })
    }

    @Test("it is deterministic, which is what makes it usable in previews and tests")
    func isDeterministic() async throws {
        let request = RoadmapRequest(goalText: "Learn to cook", horizonWeeks: 6)
        let first = try await Self.service.milestonePlan(for: request)
        let second = try await Self.service.milestonePlan(for: request)
        #expect(first == second)
    }
}
