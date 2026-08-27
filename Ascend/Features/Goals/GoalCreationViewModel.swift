import Foundation
import SwiftData
import AscendDomain
import AscendPersistence
import AscendIntelligence

/// Drives goal creation: collect the ambition, generate a roadmap on device, let the user
/// approve it, then write it to the store.
///
/// Two decisions shape this type.
///
/// **Only the first tier's steps are generated up front.** Stage two is one on-device call per
/// milestone at several seconds each, so filling a six-tier roadmap immediately would mean 30
/// to 60 seconds staring at a spinner before anything is usable. Generating the tier the user
/// is actually on takes about ten seconds total, and the rest arrive lazily as tiers unlock --
/// which is also exactly how the roadmap is designed to reveal itself.
///
/// **The user approves the plan before it is saved.** A generated roadmap is a suggestion, and
/// committing eight weeks of someone's life to the store without showing it first would be
/// presumptuous. `Phase.review` is that gate, and it makes "generate again" free.
@Observable
final class GoalCreationViewModel {

    enum Stage: Equatable {
        case milestones
        case steps(milestone: String)

        var label: String {
            switch self {
            case .milestones:            "Mapping out the milestones"
            case .steps(let milestone):  "Breaking down \u{201C}\(milestone)\u{201D}"
            }
        }
    }

    enum Phase: Equatable {
        case editing
        case planning(Stage)
        case review(RoadmapDraft)
        case saving
        case saved(String)
        case failed(AscendError)
    }

    // MARK: Inputs
    var goalText: String = ""
    var horizonWeeks: Int = 8
    var minutesPerDay: Int = 30
    var preferredDomains: Set<SkillDomain> = []

    // MARK: State
    private(set) var phase: Phase = .editing
    /// Which provider produced the draft on screen, recorded onto the `Goal` so a strange plan
    /// can be traced back to its author.
    private(set) var generatorIdentifier: String = ""

    var isGenerating: Bool {
        if case .planning = phase { return true }
        if case .saving = phase { return true }
        return false
    }

    /// The on-device provider rejects a goal under three words as `goalTooVague`, and it is
    /// kinder to disable the button than to spend twenty seconds proving it.
    var canGenerate: Bool {
        !isGenerating && Self.isPlausible(goalText)
    }

    static func isPlausible(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 12 && trimmed.split(whereSeparator: \.isWhitespace).count >= 3
    }

    var request: RoadmapRequest {
        RoadmapRequest(goalText: goalText.trimmingCharacters(in: .whitespacesAndNewlines),
                       horizonWeeks: horizonWeeks,
                       minutesPerDay: minutesPerDay,
                       preferredDomains: Array(preferredDomains).sorted { $0.rawValue < $1.rawValue })
    }

    // MARK: - Generation

    func generate(using service: any AIRoadmapService) async {
        guard Self.isPlausible(goalText) else {
            phase = .failed(.goalTooVague)
            return
        }
        generatorIdentifier = service.identifier
        phase = .planning(.milestones)

        do {
            // Stage one: the tiers. Providers validate their own output, so what arrives here
            // is already deduplicated and renumbered.
            var draft = try await service.milestonePlan(for: request)

            // Stage two, first tier only.
            if let first = draft.milestones.first {
                phase = .planning(.steps(milestone: first.title))
                draft.milestones[0].tasks = try await service.tasks(
                    for: first,
                    in: request,
                    context: PlanContext.forMilestone(at: 0, in: draft))
            }
            phase = .review(draft)
        } catch let error as AscendError {
            phase = .failed(error)
        } catch {
            phase = .failed(.generationFailed(error.localizedDescription))
        }
    }

    /// Retry the same request, for the errors where retrying could plausibly differ.
    func retry(using service: any AIRoadmapService) async {
        await generate(using: service)
    }

    /// Fall back to the deterministic planner.
    ///
    /// Offered when Apple Intelligence declines, is unavailable, or returns something the
    /// validator rejects -- so an ineligible device or a refused phrasing still ends with a
    /// usable roadmap rather than a dead end.
    func generateFromTemplate(using template: any AIRoadmapService) async {
        await generate(using: template)
    }

    func backToEditing() {
        phase = .editing
    }

    // MARK: - Saving

    @MainActor
    func save(into profile: UserProfile, context: ModelContext) {
        guard case .review(let draft) = phase else { return }
        phase = .saving
        do {
            _ = try RoadmapImporter.importDraft(draft,
                                                request: request,
                                                generatorIdentifier: generatorIdentifier,
                                                into: profile,
                                                context: context)
            phase = .saved(draft.title)
        } catch let error as AscendError {
            phase = .failed(error)
        } catch {
            phase = .failed(.invalidRoadmap(error.localizedDescription))
        }
    }
}
