import Foundation

/// One error type for the whole core, carrying its own presentation.
///
/// Copied from solvr-ai's `SolverError`: the error knows its title, its SF Symbol and
/// whether retrying is worth offering, so no view has to switch over error cases to decide
/// how to draw one. `debugDetail` keeps the underlying framework text out of the UI while
/// keeping it in the logs.
public enum AscendError: Error, LocalizedError, Equatable, Sendable {
    // MARK: Game engine
    case noProfile
    case taskNotPending(String)
    case taskNotCompleted(String)
    case noCompletionToUndo(String)
    case notReversible(String)

    // MARK: AI availability
    case appleIntelligenceUnsupportedDevice
    case appleIntelligenceDisabled
    case appleIntelligenceModelNotReady
    case unsupportedLanguage

    // MARK: AI generation
    case goalTooVague
    case goalRefused
    case contextWindowExceeded
    case generationBusy
    case generationRateLimited
    case generationFailed(String)
    case invalidRoadmap(String)

    public var title: String {
        switch self {
        case .noProfile, .taskNotPending, .taskNotCompleted, .noCompletionToUndo:
            "Something went out of sync"
        case .notReversible:
            "That can't be undone now"
        case .appleIntelligenceUnsupportedDevice:
            "This device can't run Apple Intelligence"
        case .appleIntelligenceDisabled:
            "Apple Intelligence is off"
        case .appleIntelligenceModelNotReady:
            "Apple Intelligence is still downloading"
        case .unsupportedLanguage:
            "Language not supported yet"
        case .goalTooVague:
            "Tell me a bit more"
        case .goalRefused:
            "Let's rephrase that goal"
        case .contextWindowExceeded:
            "That goal is too big to plan at once"
        case .generationBusy:
            "Still working on the last plan"
        case .generationRateLimited:
            "Apple Intelligence needs a breather"
        case .generationFailed, .invalidRoadmap:
            "Couldn't build that roadmap"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .noProfile:
            "Your character couldn't be loaded. Restarting the app should rebuild it."
        case .taskNotPending(let title):
            "\"\(title)\" isn't waiting to be done, so it can't be completed again."
        case .taskNotCompleted(let title):
            "\"\(title)\" isn't complete, so there's nothing to undo."
        case .noCompletionToUndo(let title):
            "No record of completing \"\(title)\" was found, so undoing it would guess at the reward."
        case .notReversible(let reason):
            "\(reason)"
        case .appleIntelligenceUnsupportedDevice:
            "Ascend plans roadmaps entirely on your device, which needs an iPhone 15 Pro or newer. Everything else in the app works, and you can still build roadmaps from templates."
        case .appleIntelligenceDisabled:
            "Turn on Apple Intelligence in Settings to generate roadmaps on device."
        case .appleIntelligenceModelNotReady:
            "The on-device model is still downloading. Try again shortly."
        case .unsupportedLanguage:
            "On-device planning doesn't support your language yet."
        case .goalTooVague:
            "Add a sentence about what finishing would look like, and I can break it into steps."
        case .goalRefused:
            "The on-device model declined to plan that. Rewording it around what you want to build or learn usually works."
        case .contextWindowExceeded:
            "Try a shorter horizon, or split it into two goals."
        case .generationBusy:
            "One roadmap is generated at a time. This will start as soon as the current one finishes."
        case .generationRateLimited:
            "The on-device model has been asked for a lot at once and is throttling. Waiting a minute usually clears it."
        case .generationFailed(let detail):
            "Planning stopped unexpectedly. \(detail)"
        case .invalidRoadmap(let detail):
            "The generated plan didn't make sense, so it wasn't saved. \(detail)"
        }
    }

    /// How severe this is, which decides its colour.
    ///
    /// *UI Design Principles* (Filipiuk, p98) names three notification colours: green for
    /// success, orange for warning, red for error. Everything in this app was rendering in gold,
    /// which flattened a device that cannot run the feature into the same visual weight as a
    /// goal that needs three more words. Severity separates them.
    public var severity: Severity {
        switch self {
        // Nothing is broken; the user just needs to do or wait for something.
        case .goalTooVague, .generationBusy, .generationRateLimited,
             .appleIntelligenceModelNotReady, .notReversible, .taskNotPending, .taskNotCompleted:
            .warning
        // A real failure, or a capability that is simply absent.
        case .noProfile, .noCompletionToUndo, .appleIntelligenceUnsupportedDevice,
             .appleIntelligenceDisabled, .unsupportedLanguage, .goalRefused,
             .contextWindowExceeded, .generationFailed, .invalidRoadmap:
            .error
        }
    }

    public enum Severity: Sendable, Equatable {
        case warning
        case error
    }

    public var symbolName: String {
        switch self {
        case .noProfile, .taskNotPending, .taskNotCompleted, .noCompletionToUndo, .notReversible:
            "exclamationmark.arrow.circlepath"
        case .appleIntelligenceUnsupportedDevice: "iphone.slash"
        case .appleIntelligenceDisabled:          "sparkles.slash"
        case .appleIntelligenceModelNotReady:     "arrow.down.circle.dotted"
        case .unsupportedLanguage:                "globe"
        case .goalTooVague:                       "text.bubble"
        case .goalRefused:                        "hand.raised"
        case .contextWindowExceeded:              "scissors"
        case .generationBusy:                     "hourglass"
        case .generationRateLimited:              "gauge.with.dots.needle.33percent"
        case .generationFailed, .invalidRoadmap:  "sparkles.slash"
        }
    }

    /// Whether offering a Retry button is honest. Re-running a refusal or an ineligible
    /// device produces the identical failure, and a button that always fails erodes trust
    /// faster than no button.
    public var isRetryable: Bool {
        switch self {
        case .appleIntelligenceModelNotReady, .generationBusy, .generationRateLimited,
             .generationFailed, .contextWindowExceeded:
            true
        case .noProfile, .taskNotPending, .taskNotCompleted, .noCompletionToUndo, .notReversible,
             .appleIntelligenceUnsupportedDevice, .appleIntelligenceDisabled, .unsupportedLanguage,
             .goalTooVague, .goalRefused, .invalidRoadmap:
            false
        }
    }

    /// True when the AI path is closed but the rest of the app is fine, so the UI can offer
    /// the template planner instead of an error wall.
    public var allowsTemplateFallback: Bool {
        switch self {
        case .appleIntelligenceUnsupportedDevice, .appleIntelligenceDisabled,
             .appleIntelligenceModelNotReady, .unsupportedLanguage, .goalRefused,
             .generationFailed, .invalidRoadmap, .contextWindowExceeded, .generationRateLimited:
            true
        default:
            false
        }
    }
}
