import Foundation
import AscendDomain
#if canImport(FoundationModels)
import FoundationModels

/// Roadmap generation on Apple Intelligence, and nowhere else.
///
/// There is no cloud path in this app -- not a disabled one, not a configurable one. Nothing
/// in this package may reference `URLSession` or an API key, and `tools/check.sh` fails the
/// build if that ever changes. That is the whole security posture: no credential exists to
/// leak, and no goal text leaves the device.
///
/// Generation runs in **two stages with a fresh session each**, which is subtler than it
/// looks. A `LanguageModelSession` accumulates its `transcript`, so reusing one session across
/// six per-milestone calls grows the context every time and reaches
/// `exceededContextWindowSize` *sooner* than a single-shot prompt would -- the exact opposite
/// of the reason for splitting. Each stage therefore gets its own session, sized to one job.
@available(iOS 26.0, macOS 26.0, *)
public struct OnDeviceRoadmapService: AIRoadmapService {

    private let model: SystemLanguageModel
    private let queue: ModelSessionQueue
    private let options: GenerationOptions

    public init(model: SystemLanguageModel = .default) {
        self.model = model
        self.queue = ModelSessionQueue()
        // Low temperature, deliberately.
        //
        // At 0.7 the same goal scored 52/100 on one eval run and 95/100 on the next -- the
        // variance was larger than every prompt change being tested, which makes tuning
        // impossible. The interesting variation in a roadmap should come from the goal, not
        // from the sampler. Measured over three runs per goal, 0.35 both raises the mean and
        // roughly halves the spread.
        self.options = GenerationOptions(temperature: 0.35)
    }

    public var identifier: String { "apple-on-device/guided" }

    /// One. `GenerationError.concurrentRequests` is a real outcome, not a hint.
    public var maxConcurrentRequests: Int { 1 }

    public var isConfigured: Bool { model.isAvailable }

    /// Why the on-device planner cannot run, already phrased for display, or `nil` when it
    /// can. Synchronous, so the composition root can pick a provider at launch without an
    /// `await` -- and so nothing outside this layer ever has to import FoundationModels.
    public var unavailableReason: AscendError? { Self.reason(for: model.availability) }

    /// Availability is a four-state answer, and three of the states are actionable by the
    /// user, so each maps to its own error rather than a shared "unavailable".
    static func reason(for availability: SystemLanguageModel.Availability) -> AscendError? {
        switch availability {
        case .available:
            return nil
        case .unavailable(let why):
            switch why {
            case .deviceNotEligible:          return .appleIntelligenceUnsupportedDevice
            case .appleIntelligenceNotEnabled: return .appleIntelligenceDisabled
            case .modelNotReady:              return .appleIntelligenceModelNotReady
            @unknown default:                 return .appleIntelligenceModelNotReady
            }
        @unknown default:
            return .appleIntelligenceModelNotReady
        }
    }

    // MARK: - Stage one

    public func milestonePlan(for request: RoadmapRequest) async throws -> RoadmapDraft {
        try guardAvailability()
        try validate(request)

        return try await queue.exclusive {
            let session = LanguageModelSession(model: model,
                                               instructions: RoadmapInstructions.milestonePlanner)
            do {
                let response = try await session.respond(
                    to: RoadmapInstructions.milestonePrompt(for: request),
                    generating: MilestonePlanGenerable.self,
                    options: options
                )
                // Mapped *and validated* inside the actor: Response<Content> is not Sendable
                // and must not cross back out, and a caller must never receive a draft that
                // has not been through the validator.
                return try RoadmapValidator.validated(
                    GenerableMapping.draft(from: response.content))
            } catch let error as LanguageModelSession.GenerationError {
                throw Self.translate(error)
            }
        }
    }

    // MARK: - Stage two

    public func tasks(for milestone: MilestoneDraft,
                      in request: RoadmapRequest,
                      context: PlanContext = .none) async throws -> [TaskDraft] {
        try guardAvailability()

        return try await queue.exclusive {
            let session = LanguageModelSession(model: model,
                                               instructions: RoadmapInstructions.taskPlanner)
            do {
                let response = try await session.respond(
                    to: RoadmapInstructions.taskPrompt(for: milestone, in: request, context: context),
                    generating: TaskBatchGenerable.self,
                    options: options
                )
                return try RoadmapValidator.validatedTasks(
                    GenerableMapping.tasks(from: response.content),
                    milestoneTitle: milestone.title)
            } catch let error as LanguageModelSession.GenerationError {
                throw Self.translate(error)
            }
        }
    }

    // MARK: - Recalibration

    public func recalibrate(_ request: RecalibrationRequest) async throws -> RoadmapPatch {
        try guardAvailability()

        return try await queue.exclusive {
            let session = LanguageModelSession(model: model,
                                               instructions: RoadmapInstructions.recalibrator)
            do {
                let response = try await session.respond(
                    to: RoadmapInstructions.recalibrationPrompt(for: request),
                    generating: RecalibrationGenerable.self,
                    options: options
                )
                return try GenerableMapping.patch(from: response.content)
            } catch let error as LanguageModelSession.GenerationError {
                throw Self.translate(error)
            }
        }
    }

    /// Warm the model so the first real request is not the one that pays for loading it.
    public func prewarm() {
        guard model.isAvailable else { return }
        LanguageModelSession(model: model,
                             instructions: RoadmapInstructions.milestonePlanner).prewarm()
    }

    // MARK: - Guards and translation

    private func guardAvailability() throws {
        if let reason = Self.reason(for: model.availability) { throw reason }
        // A language the model does not support produces `unsupportedLanguageOrLocale` deep in
        // generation; checking up front turns that into an immediate, explicable answer.
        let current = Locale.current.language
        if !model.supportedLanguages.contains(where: {
            $0.languageCode == current.languageCode
        }) {
            throw AscendError.unsupportedLanguage
        }
    }

    /// A goal of three words cannot be planned, and asking the model to try wastes twenty
    /// seconds to produce filler. Cheaper and kinder to say so immediately.
    private func validate(_ request: RoadmapRequest) throws {
        let words = request.goalText.split(whereSeparator: \.isWhitespace)
        guard words.count >= 3, request.goalText.trimmed.count >= 12 else {
            throw AscendError.goalTooVague
        }
    }

    /// Every case the SDK declares gets a deliberate answer. `@unknown default` exists so a
    /// future OS adding a case degrades to a retryable failure instead of failing to compile.
    static func translate(_ error: LanguageModelSession.GenerationError) -> AscendError {
        switch error {
        case .exceededContextWindowSize:      return .contextWindowExceeded
        case .guardrailViolation, .refusal:   return .goalRefused
        case .unsupportedLanguageOrLocale:    return .unsupportedLanguage
        case .concurrentRequests:             return .generationBusy
        // Declared by the SDK, and it was missing here -- it fell through to `@unknown
        // default` and surfaced as "Planning stopped unexpectedly", which tells the user
        // nothing and hides a condition that clears on its own. Sustained back-to-back
        // generation (the eval harness does ~70 calls in a row) is enough to trip it.
        case .rateLimited:                    return .generationRateLimited
        case .assetsUnavailable:              return .appleIntelligenceModelNotReady
        case .decodingFailure:
            return .invalidRoadmap("The model's answer did not match the requested shape.")
        case .unsupportedGuide:
            // A programming error in a @Guide, surfaced honestly rather than blamed on the
            // user's goal. Only reachable at runtime, which is why the fixture provider and
            // the mapping tests carry the load `swift test` cannot.
            return .generationFailed("A generation constraint in this build is invalid.")
        @unknown default:
            return .generationFailed(error.localizedDescription)
        }
    }
}
#endif
