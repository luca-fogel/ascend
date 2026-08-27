import Foundation
import SwiftData
import AscendDomain
import AscendPersistence
import AscendIntelligence

/// Fills in a tier's steps on demand.
///
/// The other half of lazy stage-two generation: `GoalCreationViewModel` generates the first
/// tier, and this generates each later tier the first time the user opens it after it unlocks.
@Observable
final class GoalDetailViewModel {

    private(set) var generatingMilestoneID: UUID?
    private(set) var error: AscendError?

    func isGenerating(_ milestone: Milestone) -> Bool {
        generatingMilestoneID == milestone.uuid
    }

    /// True when a tier is open but has no steps yet -- the state lazy generation exists for.
    func needsSteps(_ milestone: Milestone) -> Bool {
        milestone.status != .locked && milestone.tasks.isEmpty
    }

    @MainActor
    func generateSteps(for milestone: Milestone,
                       in goal: Goal,
                       using service: any AIRoadmapService,
                       context: ModelContext) async {
        guard generatingMilestoneID == nil, milestone.tasks.isEmpty else { return }
        generatingMilestoneID = milestone.uuid
        error = nil
        defer { generatingMilestoneID = nil }

        let request = RoadmapRequest(goalText: goal.title,
                                     horizonWeeks: goal.horizonWeeks,
                                     minutesPerDay: goal.minutesPerDay,
                                     preferredDomains: [goal.primaryDomain])
        let draft = MilestoneDraft(title: milestone.title,
                                   detail: milestone.detail,
                                   orderIndex: milestone.orderIndex)

        // The same context stage one gets, rebuilt from what is already stored. Without it the
        // lazily generated tiers would re-invent the steps of the tiers before them -- the
        // exact repetition PlanContext was added to stop.
        let ordered = goal.orderedMilestones
        let index = ordered.firstIndex { $0.uuid == milestone.uuid } ?? 0
        let planContext = PlanContext(
            milestoneTitles: ordered.map(\.title),
            currentIndex: index,
            plannedStepTitles: ordered.prefix(index).flatMap(\.orderedTasks).map(\.title))

        do {
            let tasks = try await service.tasks(for: draft, in: request, context: planContext)
            // Idempotent on the importer's side too, so a slow call that the user retries
            // cannot double up a tier's work.
            try RoadmapImporter.importTasks(tasks, into: milestone, context: context)
        } catch let error as AscendError {
            self.error = error
        } catch {
            self.error = .generationFailed(error.localizedDescription)
        }
    }
}
