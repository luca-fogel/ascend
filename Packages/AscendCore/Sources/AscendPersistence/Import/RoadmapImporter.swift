import Foundation
import SwiftData
import AscendDomain

/// Turns a validated `RoadmapDraft` into stored objects.
///
/// This type is the reason `AscendIntelligence` does not depend on `AscendPersistence`. The
/// generator's job ends at a plain DTO; the translation into `@Model` objects happens here, on
/// the persistence side of the boundary. So the AI layer physically cannot reach into the
/// store, and none of its tests need a `ModelContainer`.
///
/// It assumes nothing about the draft's provenance -- on-device, template, or a fixture in a
/// test all arrive by the same door, and all of them go through `RoadmapValidator` first.
@MainActor
public enum RoadmapImporter {

    /// Writes a draft as a new `Goal` and returns it.
    ///
    /// The first milestone is `.active` and the rest are `.locked`: a roadmap that presents
    /// forty steps at once is the thing this app exists to avoid.
    @discardableResult
    public static func importDraft(_ draft: RoadmapDraft,
                                   request: RoadmapRequest,
                                   generatorIdentifier: String,
                                   into profile: UserProfile,
                                   context: ModelContext,
                                   now: Date = Date(),
                                   calendar: Calendar = .current) throws -> Goal {
        var goal: Goal!
        try context.transaction {
            let target = calendar.date(byAdding: .day,
                                       value: max(1, request.horizonWeeks) * 7,
                                       to: now)
            let created = Goal(title: draft.title,
                               detail: draft.summary,
                               horizonWeeks: request.horizonWeeks,
                               minutesPerDay: request.minutesPerDay,
                               primaryDomain: draft.primaryDomain,
                               status: .active,
                               generatorIdentifier: generatorIdentifier,
                               createdAt: now,
                               targetDate: target)
            context.insert(created)
            created.profile = profile

            // Re-derived from array position rather than trusting the draft's own indices:
            // the validator already renumbered, and depending on two sources of ordering is
            // how they drift.
            for (index, milestoneDraft) in draft.milestones.enumerated() {
                let milestone = Milestone(title: milestoneDraft.title,
                                          detail: milestoneDraft.detail,
                                          orderIndex: index,
                                          status: index == 0 ? .active : .locked,
                                          createdAt: now)
                context.insert(milestone)
                milestone.goal = created

                for (taskIndex, taskDraft) in milestoneDraft.tasks.enumerated() {
                    let task = QuestTask(title: taskDraft.title,
                                         detail: taskDraft.detail,
                                         orderIndex: taskIndex,
                                         difficulty: taskDraft.difficulty,
                                         cadence: taskDraft.cadence,
                                         domain: taskDraft.domain,
                                         state: .pending,
                                         createdAt: now)
                    context.insert(task)
                    task.milestone = milestone
                }
            }
            goal = created
        }
        return goal
    }

    /// Attaches a recalibration side-quest to an existing goal.
    ///
    /// Inserted at the front with a negative `orderIndex` so it sorts ahead of the remaining
    /// plan without renumbering everything behind it -- the way back has to be the next thing
    /// the user sees, not item seven.
    @discardableResult
    public static func importPatch(_ patch: RoadmapPatch,
                                   into goal: Goal,
                                   context: ModelContext,
                                   now: Date = Date()) throws -> Milestone? {
        guard let questDraft = patch.sideQuest else { return nil }
        var created: Milestone!
        try context.transaction {
            let minIndex = goal.milestones.map(\.orderIndex).min() ?? 0
            let milestone = Milestone(title: questDraft.title,
                                      detail: questDraft.detail,
                                      orderIndex: minIndex - 1,
                                      status: .active,
                                      isSideQuest: true,
                                      createdAt: now)
            context.insert(milestone)
            milestone.goal = goal

            for (index, taskDraft) in questDraft.tasks.enumerated() {
                let task = QuestTask(title: taskDraft.title,
                                     detail: taskDraft.detail,
                                     orderIndex: index,
                                     difficulty: taskDraft.difficulty,
                                     cadence: taskDraft.cadence,
                                     domain: taskDraft.domain,
                                     state: .pending,
                                     isSideQuest: true,
                                     createdAt: now)
                context.insert(task)
                task.milestone = milestone
            }
            created = milestone
        }
        return created
    }
}

extension RoadmapImporter {
    /// Adds generated steps to a milestone that has none yet.
    ///
    /// This is what makes lazy stage-two generation possible. Generating every tier's steps up
    /// front means six sequential on-device calls -- 30 to 60 seconds before the user sees
    /// anything usable. Generating only the tier they are actually on turns that into a few
    /// seconds, and the rest arrive as tiers unlock.
    ///
    /// Idempotent: a milestone that already has steps is left alone, so a double-tap or a
    /// retried request cannot duplicate a tier's work.
    @discardableResult
    public static func importTasks(_ drafts: [TaskDraft],
                                   into milestone: Milestone,
                                   context: ModelContext,
                                   now: Date = Date()) throws -> [QuestTask] {
        guard milestone.tasks.isEmpty else { return milestone.orderedTasks }
        var created: [QuestTask] = []
        try context.transaction {
            for (index, draft) in drafts.enumerated() {
                let task = QuestTask(title: draft.title,
                                     detail: draft.detail,
                                     orderIndex: index,
                                     difficulty: draft.difficulty,
                                     cadence: draft.cadence,
                                     domain: draft.domain,
                                     state: .pending,
                                     createdAt: now)
                context.insert(task)
                task.milestone = milestone
                created.append(task)
            }
        }
        return created
    }
}
