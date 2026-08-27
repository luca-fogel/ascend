import Foundation
import AscendDomain

/// A roadmap generator with no model behind it.
///
/// Not a mock. This ships, and it is load-bearing in three situations that are all real:
///
/// - **Ineligible hardware.** Apple Intelligence needs an iPhone 15 Pro or newer. On anything
///   older `availability` reports `.deviceNotEligible` *on iOS 26*, so a device-version floor
///   never removes this case. Those users still get a usable app.
/// - **Previews and demo mode.** Deterministic output, no model download, no eligibility.
/// - **The test suite.** Apple Intelligence cannot run under `swift test`, so this provider
///   is what exercises the validator, the importer and the whole completion pipeline on every
///   commit. Solvr-ai's `FixtureSolutionProvider` earns its keep the same way.
///
/// Output is intentionally generic where the on-device model would be specific. It is honest
/// scaffolding, and the UI says so rather than passing it off as a generated plan.
public struct TemplateRoadmapService: AIRoadmapService {

    private let simulatedLatency: Duration

    /// Latency is simulated by default so loading states stay reachable in previews and demo
    /// mode. A provider that returns instantly makes every spinner dead code, and the first
    /// time anyone sees the loading state is in production.
    public init(simulatedLatency: Duration = .milliseconds(400)) {
        self.simulatedLatency = simulatedLatency
    }

    public var identifier: String { "template/v1" }
    public var maxConcurrentRequests: Int { 4 }
    public var isConfigured: Bool { true }
    public var unavailableReason: AscendError? { nil }

    public func milestonePlan(for request: RoadmapRequest) async throws -> RoadmapDraft {
        try await pause()
        let domain = request.preferredDomains.first ?? .discipline
        let tiers = Self.tiers(forHorizonWeeks: request.horizonWeeks)

        let milestones = tiers.enumerated().map { index, tier in
            MilestoneDraft(title: tier.title,
                           detail: tier.detail,
                           orderIndex: index,
                           tasks: [])
        }
        return try RoadmapValidator.validated(
            RoadmapDraft(title: Self.planTitle(for: request.goalText),
                         summary: "A \(request.horizonWeeks)-week starting structure for \(request.goalText.condensed). Built from a template, so edit it freely.",
                         primaryDomain: domain,
                         milestones: milestones)
        )
    }

    public func tasks(for milestone: MilestoneDraft,
                      in request: RoadmapRequest,
                      context: PlanContext = .none) async throws -> [TaskDraft] {
        try await pause()
        let domain = request.preferredDomains.first ?? .discipline
        let minutes = max(5, request.minutesPerDay)

        return try RoadmapValidator.validatedTasks([
            TaskDraft(title: "Spend \(minutes) minutes on \(milestone.title.lowercasedFirst)",
                      detail: "The daily block that moves this milestone forward.",
                      difficulty: .medium, cadence: .daily, domain: domain, orderIndex: 0),
            TaskDraft(title: "Write down one thing you learned",
                      detail: "Two sentences is enough. Keeping a record is what makes progress visible later.",
                      difficulty: .trivial, cadence: .daily, domain: .intellect, orderIndex: 1),
            TaskDraft(title: "Decide what \"done\" means for this milestone",
                      detail: "A checkpoint you can actually recognise reaching.",
                      difficulty: .easy, cadence: .oneShot, domain: .discipline, orderIndex: 2),
            TaskDraft(title: "Review the week and adjust the plan",
                      detail: "Cut what is not working rather than pushing harder at it.",
                      difficulty: .easy, cadence: .weekly, domain: .discipline, orderIndex: 3),
        ], milestoneTitle: milestone.title)
    }

    public func recalibrate(_ request: RecalibrationRequest) async throws -> RoadmapPatch {
        try await pause()
        let quest = MilestoneDraft(
            title: "Back on the path",
            detail: "A deliberately small return after \(request.missedDays) day\(request.missedDays == 1 ? "" : "s") away.",
            orderIndex: 0,
            tasks: try RoadmapValidator.validatedTasks([
                TaskDraft(title: "Do the smallest useful version of one step",
                          detail: "Five minutes counts. Restarting matters more than the size of the restart.",
                          difficulty: .trivial, cadence: .oneShot, domain: .discipline, orderIndex: 0),
                TaskDraft(title: "Pick the one step to resume tomorrow",
                          detail: "Choosing in advance removes the decision when it is hardest to make.",
                          difficulty: .trivial, cadence: .oneShot, domain: .discipline, orderIndex: 1),
            ], milestoneTitle: "Back on the path")
        )
        return RoadmapPatch(
            rationale: "Missing \(request.missedDays) day\(request.missedDays == 1 ? "" : "s") does not undo what you already built. This side-quest is smaller than the plan on purpose -- clear it and the roadmap picks up where it left off.",
            sideQuest: quest
        )
    }

    private func pause() async throws {
        guard simulatedLatency > .zero else { return }
        try await Task.sleep(for: simulatedLatency)
    }

    private static func planTitle(for goalText: String) -> String {
        let condensed = goalText.condensed
        guard !condensed.isEmpty else { return "Your plan" }
        return String(condensed.prefix(60))
    }

    private struct Tier { let title: String; let detail: String }

    /// Fewer, larger tiers for a short horizon. Padding a two-week plan to six milestones is
    /// how a template starts feeling like a form to fill in.
    private static func tiers(forHorizonWeeks weeks: Int) -> [Tier] {
        let all = [
            Tier(title: "Set the ground rules",
                 detail: "Decide when you will work on this, and what the minimum acceptable day looks like."),
            Tier(title: "Build the daily habit",
                 detail: "Consistency before intensity. The aim is a streak, not a personal best."),
            Tier(title: "Raise the difficulty",
                 detail: "Once showing up is automatic, make the work itself harder."),
            Tier(title: "Produce something real",
                 detail: "Turn accumulated practice into one finished, visible result."),
            Tier(title: "Consolidate and review",
                 detail: "Keep what worked, cut what did not, and decide what comes after this goal."),
        ]
        switch weeks {
        case ..<3:  return Array(all.prefix(3))
        case 3..<8: return Array(all.prefix(4))
        default:    return all
        }
    }
}

extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
