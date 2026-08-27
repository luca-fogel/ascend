import Foundation

/// The swap seam for roadmap generation.
///
/// Shaped after `SolutionProvider` in solvr-ai: the provider owns its own prompts, its own
/// concurrency limit and its own availability reporting, so nothing upstream can tell which
/// backend answered. Today the only real implementation is Apple Intelligence on device and
/// there is deliberately no network path at all -- `tools/check.sh` fails the build if
/// `URLSession` or an API-key literal ever appears in this package.
///
/// Generation is **two calls, not one**. The on-device model has a small context window and
/// `LanguageModelSession.GenerationError.exceededContextWindowSize` is a real outcome, so a
/// twelve-week roadmap is planned as milestones first and then filled in per milestone. That
/// also lets the UI reveal the plan as it arrives instead of after everything is done.
public protocol AIRoadmapService: Sendable {

    /// Log-safe configuration identifier, e.g. `"apple-on-device/guided"`. Recorded on every
    /// `Goal` so a strange roadmap can be traced to the thing that produced it.
    var identifier: String { get }

    /// How many generations may be in flight. On-device is 1: `GenerationError`
    /// has a `concurrentRequests` case, and exceeding it is an error, not a queue.
    var maxConcurrentRequests: Int { get }

    /// Whether this provider can run right now.
    var isConfigured: Bool { get }

    /// Why it cannot, if it cannot -- already phrased for display.
    var unavailableReason: AscendError? { get }

    /// Stage one: the tiers. Returns a draft whose milestones have no tasks yet.
    func milestonePlan(for request: RoadmapRequest) async throws -> RoadmapDraft

    /// Stage two: the daily steps for one tier.
    ///
    /// `context` carries the rest of the plan. Without it a tier is detailed in isolation and
    /// later tiers re-invent earlier ones almost verbatim.
    func tasks(for milestone: MilestoneDraft,
               in request: RoadmapRequest,
               context: PlanContext) async throws -> [TaskDraft]

    /// Turn a broken streak into a route back rather than a dead end.
    func recalibrate(_ request: RecalibrationRequest) async throws -> RoadmapPatch
}

extension AIRoadmapService {
    /// Convenience: run both stages and return a filled roadmap.
    ///
    /// Sequential by design -- see `maxConcurrentRequests`. A `TaskGroup` here would trip
    /// `concurrentRequests` on the on-device provider.
    public func fullRoadmap(for request: RoadmapRequest) async throws -> RoadmapDraft {
        var draft = try await milestonePlan(for: request)
        for index in draft.milestones.indices {
            // Built fresh each iteration so each tier sees the steps committed before it.
            let context = PlanContext.forMilestone(at: index, in: draft)
            draft.milestones[index].tasks = try await tasks(for: draft.milestones[index],
                                                            in: request,
                                                            context: context)
        }
        return draft
    }
}
