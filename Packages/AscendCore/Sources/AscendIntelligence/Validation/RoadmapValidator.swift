import Foundation
import AscendDomain

/// The gate between model output and the store.
///
/// `@Guide` constrains generation; it does not guarantee it. Everything downstream --
/// `orderIndex` uniqueness, non-empty titles, a plan that is not forty steps of nothing --
/// is this type's job, and it runs identically for the on-device provider and the template
/// one. Nothing writes to SwiftData without passing through here.
///
/// It repairs what is unambiguous and rejects what is not. Renumbering `orderIndex` is a
/// repair, because ordering is implied by array position and the model's numbering is
/// redundant. Inventing a missing title is not, because a plan with a blank milestone is a
/// plan the user cannot act on, and a plausible-looking placeholder hides that.
public enum RoadmapValidator {

    public static let maxMilestones = 12
    public static let maxTasksPerMilestone = 15
    public static let maxTitleLength = 120

    /// Normalises a draft or explains why it cannot be used.
    public static func validated(_ draft: RoadmapDraft) throws -> RoadmapDraft {
        let title = draft.title.condensed
        guard !title.isEmpty else {
            throw AscendError.invalidRoadmap("The plan had no title.")
        }
        guard !draft.milestones.isEmpty else {
            throw AscendError.invalidRoadmap("The plan had no milestones.")
        }
        guard draft.milestones.count <= maxMilestones else {
            throw AscendError.invalidRoadmap("The plan had \(draft.milestones.count) milestones, which is more than a person can hold.")
        }

        var seenTitles = Set<String>()
        var milestones: [MilestoneDraft] = []

        for (index, milestone) in draft.milestones.enumerated() {
            let cleanTitle = milestone.title.condensed
            guard !cleanTitle.isEmpty else {
                throw AscendError.invalidRoadmap("Milestone \(index + 1) had no title.")
            }
            // A duplicate tier is the most common way a small model pads a plan to hit a
            // count guide. Dropping it silently is right -- it carries no information.
            let key = cleanTitle.lowercased()
            guard seenTitles.insert(key).inserted else { continue }

            guard milestone.tasks.count <= maxTasksPerMilestone else {
                throw AscendError.invalidRoadmap("\"\(cleanTitle)\" had \(milestone.tasks.count) steps, which is too many to be a milestone.")
            }

            milestones.append(
                MilestoneDraft(title: String(cleanTitle.prefix(maxTitleLength)),
                               detail: milestone.detail.condensed,
                               // Renumbered from position: array order is the real ordering,
                               // and the model's own indices are frequently duplicated.
                               orderIndex: milestones.count,
                               tasks: try validatedTasks(milestone.tasks, milestoneTitle: cleanTitle))
            )
        }

        guard !milestones.isEmpty else {
            throw AscendError.invalidRoadmap("Every milestone in the plan was a duplicate.")
        }

        return RoadmapDraft(title: String(title.prefix(maxTitleLength)),
                            summary: draft.summary.condensed,
                            primaryDomain: draft.primaryDomain,
                            milestones: milestones)
    }

    public static func validatedTasks(_ tasks: [TaskDraft], milestoneTitle: String) throws -> [TaskDraft] {
        var seen = Set<String>()
        var result: [TaskDraft] = []

        for task in tasks {
            let cleanTitle = task.title.condensed
            guard !cleanTitle.isEmpty else {
                throw AscendError.invalidRoadmap("A step in \"\(milestoneTitle)\" had no title.")
            }
            guard seen.insert(cleanTitle.lowercased()).inserted else { continue }
            result.append(
                TaskDraft(title: String(cleanTitle.prefix(maxTitleLength)),
                          detail: task.detail.condensed,
                          difficulty: task.difficulty,
                          cadence: task.cadence,
                          domain: task.domain,
                          orderIndex: result.count)
            )
        }
        return result
    }
}

extension String {
    /// Trimmed, with internal runs of whitespace collapsed. Generated text arrives with
    /// stray newlines and double spaces that look like layout bugs once rendered.
    var condensed: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
