import Foundation
import AscendDomain
#if canImport(FoundationModels)
import FoundationModels

/// Turning generated content into domain values, rejecting rather than guessing.
///
/// `@Guide(.anyOf(...))` constrains generation but is not a runtime guarantee, so every enum
/// crossing this boundary is parsed and a miss throws `AscendError.invalidRoadmap`. Quietly
/// defaulting an unrecognised difficulty to `.medium` would be worse than failing: the user
/// gets a plan that silently misprices every step, and nothing in the logs says why.
@available(iOS 26.0, macOS 26.0, *)
enum GenerableMapping {

    static func domain(_ raw: String) throws -> SkillDomain {
        guard let value = SkillDomain(rawValue: raw.trimmed) else {
            throw AscendError.invalidRoadmap("Unrecognised skill area \"\(raw)\".")
        }
        return value
    }

    static func difficulty(_ raw: String) throws -> TaskDifficulty {
        guard let value = TaskDifficulty(rawValue: raw.trimmed) else {
            throw AscendError.invalidRoadmap("Unrecognised difficulty \"\(raw)\".")
        }
        return value
    }

    static func cadence(_ raw: String) throws -> TaskCadence {
        guard let value = TaskCadence(rawValue: raw.trimmed) else {
            throw AscendError.invalidRoadmap("Unrecognised cadence \"\(raw)\".")
        }
        return value
    }

    static func draft(from plan: MilestonePlanGenerable) throws -> RoadmapDraft {
        let milestones = plan.milestones.enumerated().map { index, milestone in
            MilestoneDraft(title: milestone.title.trimmed,
                           detail: milestone.detail.trimmed,
                           orderIndex: index,
                           tasks: [])
        }
        return RoadmapDraft(title: plan.title.trimmed,
                            summary: plan.summary.trimmed,
                            primaryDomain: try domain(plan.primaryDomain),
                            milestones: milestones)
    }

    static func tasks(from batch: TaskBatchGenerable) throws -> [TaskDraft] {
        try batch.tasks.enumerated().map { index, task in
            TaskDraft(title: task.title.trimmed,
                      detail: task.detail.trimmed,
                      difficulty: try difficulty(task.difficulty),
                      cadence: try cadence(task.cadence),
                      domain: try domain(task.domain),
                      orderIndex: index)
        }
    }

    static func patch(from generated: RecalibrationGenerable) throws -> RoadmapPatch {
        let tasks = try generated.sideQuestTasks.enumerated().map { index, task in
            TaskDraft(title: task.title.trimmed,
                      detail: task.detail.trimmed,
                      difficulty: try difficulty(task.difficulty),
                      cadence: try cadence(task.cadence),
                      domain: try domain(task.domain),
                      orderIndex: index)
        }
        let quest = MilestoneDraft(title: generated.sideQuestTitle.trimmed,
                                   detail: generated.sideQuestDetail.trimmed,
                                   orderIndex: 0,
                                   tasks: tasks)
        return RoadmapPatch(rationale: generated.rationale.trimmed,
                            sideQuest: quest.title.isEmpty ? nil : quest)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
#endif
