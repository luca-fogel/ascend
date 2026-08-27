import Testing
import Foundation
import AscendDomain
@testable import AscendIntelligence
#if canImport(FoundationModels)
import FoundationModels

/// What can honestly be tested about the on-device provider without a model.
///
/// Apple Intelligence cannot run under `swift test` -- there is no eligible device, and a test
/// gated on `SystemLanguageModel.isAvailable` would be permanently skipped on CI and read as
/// passing. So this suite covers the provider's *pure* logic: availability mapping and the
/// string-to-enum parsing at the boundary. The generation path itself is covered by
/// `TemplateRoadmapService` end to end, and confirmed on device by the Settings screen.
@Suite("On-device provider: pure logic")
struct OnDeviceMappingTests {

    @Test("each unavailability reason maps to its own actionable error, not a shared one")
    func availabilityMapping() {
        // Three of the four states are things the user can act on, so collapsing them into one
        // "unavailable" message would throw away the only useful information in the answer.
        #expect(OnDeviceRoadmapService.reason(for: .available) == nil)
        #expect(OnDeviceRoadmapService.reason(for: .unavailable(.deviceNotEligible))
                == .appleIntelligenceUnsupportedDevice)
        #expect(OnDeviceRoadmapService.reason(for: .unavailable(.appleIntelligenceNotEnabled))
                == .appleIntelligenceDisabled)
        #expect(OnDeviceRoadmapService.reason(for: .unavailable(.modelNotReady))
                == .appleIntelligenceModelNotReady)
    }

    @Test("an ineligible device still offers the template planner rather than an error wall")
    func ineligibleDeviceFallsBack() {
        // Apple Intelligence needs an iPhone 15 Pro or newer, so this state is reachable *on
        // iOS 26* -- a version floor never removes it. Those users must still get an app.
        let reason = OnDeviceRoadmapService.reason(for: .unavailable(.deviceNotEligible))
        #expect(reason?.allowsTemplateFallback == true)
        // And no Retry button, because retrying an ineligible device fails identically.
        #expect(reason?.isRetryable == false)
    }

    @Test("a still-downloading model is retryable, unlike an ineligible one")
    func modelNotReadyIsRetryable() {
        #expect(OnDeviceRoadmapService.reason(for: .unavailable(.modelNotReady))?.isRetryable == true)
    }

    @Test("guided enum strings parse, and anything unexpected is rejected not defaulted")
    func enumParsing() throws {
        // @Guide(.anyOf(...)) constrains generation but is not a runtime guarantee. Quietly
        // defaulting an unrecognised difficulty to .medium would misprice every step in the
        // plan and leave nothing in the logs to explain it.
        #expect(try GenerableMapping.domain("fitness") == .fitness)
        #expect(try GenerableMapping.domain("  intellect  ") == .intellect)
        #expect(try GenerableMapping.difficulty("epic") == .epic)
        #expect(try GenerableMapping.cadence("oneShot") == .oneShot)

        #expect(throws: (any Error).self) { _ = try GenerableMapping.domain("Fitness") }
        #expect(throws: (any Error).self) { _ = try GenerableMapping.domain("productivity") }
        #expect(throws: (any Error).self) { _ = try GenerableMapping.difficulty("very hard") }
        #expect(throws: (any Error).self) { _ = try GenerableMapping.cadence("") }
    }

    @Test("every SkillDomain, difficulty and cadence case survives a round trip")
    func allCasesRoundTrip() throws {
        // The guides are built from `allCases`, so a newly added case is offered to the model
        // the moment it exists. This is what stops the mapper falling behind the enum.
        for domain in SkillDomain.allCases {
            #expect(try GenerableMapping.domain(domain.rawValue) == domain)
        }
        for difficulty in TaskDifficulty.allCases {
            #expect(try GenerableMapping.difficulty(difficulty.rawValue) == difficulty)
        }
        for cadence in TaskCadence.allCases {
            #expect(try GenerableMapping.cadence(cadence.rawValue) == cadence)
        }
    }

    @Test("the provider declares a concurrency limit of one, matching the framework's error")
    func serialisesRequests() {
        // GenerationError.concurrentRequests is a real outcome, so overlapping generations are
        // an error rather than a queue and the app has to do the queueing itself.
        #expect(OnDeviceRoadmapService().maxConcurrentRequests == 1)
        #expect(OnDeviceRoadmapService().identifier == "apple-on-device/guided")
    }

    @Test("a second concurrent generation fails fast instead of silently queueing")
    func queueRejectsOverlap() async throws {
        let queue = ModelSessionQueue()
        // Hold the slot, then attempt a second entry from inside it.
        await #expect(throws: AscendError.generationBusy) {
            try await queue.exclusive {
                try await queue.exclusive { 1 }
            }
        }
        // And the slot is released afterwards, so the next real request works.
        let value = try await queue.exclusive { 42 }
        #expect(value == 42)
    }

    @Test("the slot is released even when the work throws -- the leak this guards against")
    func queueReleasesOnThrow() async throws {
        let queue = ModelSessionQueue()
        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            try await queue.exclusive { throw Boom() }
        }
        let value = try await queue.exclusive { 7 }
        #expect(value == 7)
    }
}
#endif
