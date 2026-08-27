import Foundation
import AscendDomain
#if canImport(FoundationModels)
import FoundationModels

/// Serialises access to the on-device model.
///
/// `LanguageModelSession.GenerationError` has a `concurrentRequests` case, so overlapping
/// generations are an error rather than a queue -- the app has to do the queueing.
///
/// Two things this actor deliberately does *not* do:
///
/// **It never returns a `Response<Content>` or a `ResponseStream`.** Neither is `Sendable`
/// (checked in the SDK swiftinterface: `public struct Response<Content> where Content:
/// Generable`, no conformance; `ResponseStream` is returned as `sending`). Work is therefore
/// mapped to a domain DTO *inside* the actor and only the DTO crosses back out.
///
/// **It does not exist to keep generation off the main thread.** `respond(to:generating:)` is
/// `nonisolated(nonsending)` and inference runs out of process, so calling it from
/// `@MainActor` does not block the UI. If a future change appears to need `Task.detached` for
/// responsiveness, that diagnosis is wrong -- and acting on it risks sending a `@Model` across
/// an isolation boundary, which (because `@Model` attaches `Sendable`) compiles silently.
@available(iOS 26.0, macOS 26.0, *)
actor ModelSessionQueue {
    private var isBusy = false

    /// Runs `work` with exclusive access, throwing rather than waiting if something is already
    /// in flight. Failing fast is the honest behaviour: a roadmap takes tens of seconds, and a
    /// silent queue would leave the user staring at a spinner with no idea they are second in
    /// line. `AscendError.generationBusy` is retryable and says so.
    func exclusive<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        guard !isBusy else { throw AscendError.generationBusy }
        isBusy = true
        defer { isBusy = false }
        return try await work()
    }
}
#endif
