import Foundation
import AscendDomain
#if canImport(FoundationModels)
import FoundationModels

// MARK: - The shapes the on-device model fills in
//
// These are mirrors of the plain DTOs in AscendDomain, not replacements for them. Three
// reasons the duplication is worth it:
//
// 1. `@Generable` is a FoundationModels macro, so a Generable DTO would drag the framework
//    into the domain layer and make every mapping test need an Apple-Intelligence-capable
//    host.
// 2. The wire shape and the domain shape want different things. `Generable` conforms only to
//    Bool, String, Int, Float, Double, Decimal, Array and Never -- there is **no `Date` and
//    no `UUID`** (verified in the SDK swiftinterface). Deadlines therefore cross as `Int` day
//    offsets, which is what you want anyway: small on-device models are unreliable with
//    absolute dates and perfectly fine with "day 14".
// 3. Enums cross as guided `String`s. `@Guide(.anyOf(...))` constrains generation to the exact
//    case set, and the mapper rejects anything else rather than silently defaulting.
//
// Optionals are avoided throughout: making nil explicit in generated content requires
// `@Generable(description:representNilExplicitlyInGeneratedContent:)`, which is iOS 26.4,
// above this app's 26.0 floor. Empty string and 0 are the sentinels.

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A tiered plan that breaks one ambitious goal into ordered milestones.")
struct MilestonePlanGenerable {

    @Guide(description: "Between three and seven milestones, ordered from first to last.",
           .count(3...7))
    var milestones: [MilestoneGenerable]

    @Guide(description: "Which area of life this goal mainly develops.",
           .anyOf(SkillDomain.allCases.map(\.rawValue)))
    var primaryDomain: String

    @Guide(description: "One or two sentences describing what finishing this goal looks like.")
    var summary: String

    /// Declared last on purpose: the model names the plan after it has written it, which
    /// yields a title that describes the actual roadmap instead of echoing the prompt.
    @Guide(description: "A short, concrete title for the whole plan. No more than six words.")
    var title: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "One tier of a roadmap: a meaningful checkpoint on the way to the goal.")
struct MilestoneGenerable {

    @Guide(description: "A short title naming the capability gained, not a quantity reached. Describe what the person will be able to do, not how many things they will have made.")
    var title: String

    @Guide(description: "The observable test for being done: what a person could point at. One sentence. Do not restate the title.")
    var detail: String

    @Guide(description: "Which day of the plan this tier should be reached by, counting from day 1.",
           .range(1...365))
    var targetDayOffset: Int
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "The concrete repeatable steps that satisfy one milestone.")
struct TaskBatchGenerable {

    @Guide(description: "Between three and eight steps for this milestone, ordered.",
           .count(3...8))
    var tasks: [TaskGenerable]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A single action a person can actually do in one sitting.")
struct TaskGenerable {

    @Guide(description: "An imperative step that states an amount: a digit plus a unit drawn from this goal's own subject matter (minutes, pages, reps, sets, words, lines, items, takes). Never a bare verb phrase, and never a unit borrowed from an unrelated field.")
    var title: String

    @Guide(description: "A method or constraint the title cannot hold, or how to tell it was done well. Never restate the title. Empty string if the title says everything.")
    var detail: String

    @Guide(description: "How demanding this step is.",
           .anyOf(TaskDifficulty.allCases.map(\.rawValue)))
    var difficulty: String

    @Guide(description: "How often it repeats. Use 'daily' for habits, 'oneShot' for one-time work.",
           .anyOf(TaskCadence.allCases.map(\.rawValue)))
    var cadence: String

    @Guide(description: "Which area of life this step develops.",
           .anyOf(SkillDomain.allCases.map(\.rawValue)))
    var domain: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "An encouraging way back onto a plan after missed days.")
struct RecalibrationGenerable {

    @Guide(description: "Two sentences, warm and practical, on why falling behind is recoverable. Never scolding.")
    var rationale: String

    @Guide(description: "A short title for a small catch-up quest that rebuilds momentum.")
    var sideQuestTitle: String

    @Guide(description: "What the catch-up quest involves, in one or two sentences.")
    var sideQuestDetail: String

    @Guide(description: "Two or three deliberately easy steps to restart with.", .count(2...3))
    var sideQuestTasks: [TaskGenerable]
}
#endif
