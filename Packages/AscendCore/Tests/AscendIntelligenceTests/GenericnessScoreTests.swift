import Testing
import Foundation
import AscendDomain
@testable import AscendIntelligence

@Suite("Genericness score")
struct GenericnessScoreTests {

    static func draft(_ tasks: [TaskDraft], title: String = "Learn SwiftUI") -> RoadmapDraft {
        RoadmapDraft(title: title, summary: "A plan", primaryDomain: .intellect,
                     milestones: [MilestoneDraft(title: "Foundations", detail: "Done when it runs",
                                                 orderIndex: 0, tasks: tasks)])
    }

    static func task(_ title: String,
                     detail: String = "",
                     difficulty: TaskDifficulty = .medium,
                     cadence: TaskCadence = .daily) -> TaskDraft {
        TaskDraft(title: title, detail: detail, difficulty: difficulty,
                  cadence: cadence, domain: .intellect, orderIndex: 0)
    }

    @Test("a step with a number is concrete; a bare verb phrase is not")
    func concretenessDetection() {
        #expect(GenericnessScore.isConcrete("Read 20 pages"))
        #expect(GenericnessScore.isConcrete("Practise for 25 minutes"))
        #expect(GenericnessScore.isConcrete("Write two paragraphs"))
        #expect(!GenericnessScore.isConcrete("Draft lyrics"))
        #expect(!GenericnessScore.isConcrete("Record a song"))
        #expect(!GenericnessScore.isConcrete("Improve your technique"))
    }

    @Test("filler phrases are caught wherever they appear in the plan")
    func fillerDetection() {
        let score = GenericnessScore.evaluate(
            Self.draft([Self.task("Research the topic"),
                        Self.task("Stay motivated", detail: "Track your progress weekly")]),
            goalText: "Learn SwiftUI")
        #expect(score.fillerHits.contains("research"))
        #expect(score.fillerHits.contains("stay motivated"))
        #expect(score.fillerHits.contains("track your progress"))
    }

    @Test("a step that just restates the goal is flagged as an echo")
    func goalEchoDetection() {
        let score = GenericnessScore.evaluate(
            Self.draft([Self.task("Learn SwiftUI properly")]),
            goalText: "Learn SwiftUI well enough to ship an app")
        #expect(!score.goalEchoes.isEmpty)
    }

    @Test("a specific, varied plan scores near the top")
    func goodPlanScoresHigh() {
        let score = GenericnessScore.evaluate(
            Self.draft([
                Self.task("Read 20 pages of the SwiftUI guide", difficulty: .easy, cadence: .daily),
                Self.task("Write 25 lines of a list view", difficulty: .hard, cadence: .daily),
                Self.task("Ship 1 build to TestFlight", difficulty: .medium, cadence: .oneShot),
                Self.task("Review the week in 15 minutes", difficulty: .trivial, cadence: .weekly),
            ]),
            goalText: "Learn SwiftUI well enough to ship an app")
        #expect(score.score >= 90, "scored \(score.score)")
        #expect(score.concreteness == 1)
        #expect(score.distinctCadences == 3)
    }

    @Test("the plan this scorer was written to catch scores badly")
    func realWorldGenericPlanScoresLow() {
        // Verbatim from an actual on-device run before the prompts were tuned.
        let score = GenericnessScore.evaluate(
            Self.draft([
                Self.task("Brainstorm song ideas", difficulty: .easy),
                Self.task("Draft lyrics", difficulty: .easy),
                Self.task("Pick a tune", difficulty: .easy),
                Self.task("Record a rough demo", difficulty: .easy),
            ], title: "Develop Songwriting Creativity"),
            goalText: "Write and record five original songs")
        #expect(score.score <= 55, "scored \(score.score)")
        #expect(score.concreteness == 0)
        #expect(score.distinctCadences == 1)
    }

    @Test("an empty plan scores zero rather than dividing by zero")
    func emptyPlanIsSafe() {
        let score = GenericnessScore.evaluate(Self.draft([]), goalText: "Anything")
        #expect(score.score == 0)
        #expect(score.concreteness == 0)
        #expect(!score.concreteness.isNaN)
    }
}

@Suite("Plan context")
struct PlanContextTests {

    @Test("context for a tier carries the arc and only the steps committed before it")
    func contextIsBuiltFromEarlierTiersOnly() {
        let draft = RoadmapDraft(
            title: "Plan", summary: "", primaryDomain: .intellect,
            milestones: (0..<3).map { index in
                MilestoneDraft(title: "Tier \(index)", detail: "", orderIndex: index,
                               tasks: [TaskDraft(title: "Step \(index)", detail: "",
                                                 difficulty: .easy, cadence: .daily,
                                                 domain: .intellect, orderIndex: 0)])
            })

        let first = PlanContext.forMilestone(at: 0, in: draft)
        #expect(first.milestoneTitles == ["Tier 0", "Tier 1", "Tier 2"])
        #expect(first.currentIndex == 0)
        // Nothing precedes the first tier, so there is nothing to avoid repeating.
        #expect(first.plannedStepTitles.isEmpty)

        let third = PlanContext.forMilestone(at: 2, in: draft)
        #expect(third.currentIndex == 2)
        #expect(third.plannedStepTitles == ["Step 0", "Step 1"])
    }

    @Test("the prompt shows the arc, marks the current tier, and lists what not to repeat")
    func promptCarriesTheContext() {
        let context = PlanContext(milestoneTitles: ["Foundations", "Build", "Ship"],
                                  currentIndex: 1,
                                  plannedStepTitles: ["Read 20 pages", "Write 25 lines"])
        let prompt = RoadmapInstructions.taskPrompt(
            for: MilestoneDraft(title: "Build", detail: "Done when it runs", orderIndex: 1),
            in: RoadmapRequest(goalText: "Learn SwiftUI", minutesPerDay: 45),
            context: context)

        #expect(prompt.contains("milestone 2 of 3"))
        #expect(prompt.contains("> 2. Build"))
        #expect(prompt.contains("Read 20 pages"))
        #expect(prompt.contains("do not repeat"))
        #expect(prompt.contains("45 minutes"))
    }

    @Test("a single-tier plan does not print an arc it has no need for")
    func singleTierPromptStaysShort() {
        let prompt = RoadmapInstructions.taskPrompt(
            for: MilestoneDraft(title: "Only tier", detail: "", orderIndex: 0),
            in: RoadmapRequest(goalText: "Learn SwiftUI"),
            context: PlanContext(milestoneTitles: ["Only tier"], currentIndex: 0))
        #expect(!prompt.contains("of 1 in this plan"))
    }

    @Test("the banned-phrase list actually reaches the instructions")
    func bannedPhrasesAreInThePrompt() {
        // If this ever fails, the filler rules were silently dropped from the prompt while the
        // scorer kept measuring for them.
        #expect(RoadmapInstructions.taskPlanner.contains("research"))
        #expect(RoadmapInstructions.milestonePlanner.contains("stay motivated"))
        for phrase in ["research", "stay motivated", "set goals"] {
            #expect(GenericnessScore.fillerPhrases.contains(phrase))
        }
    }
}

@Suite("Error surface")
struct AscendErrorSurfaceTests {

    @Test("rate limiting is its own error, retryable, and not a generic failure")
    func rateLimitIsDistinct() {
        // It was previously absorbed by `@unknown default` and shown as "Planning stopped
        // unexpectedly" -- the exact thing @unknown default is good at hiding.
        let error = AscendError.generationRateLimited
        #expect(error.isRetryable)
        #expect(error.allowsTemplateFallback)
        #expect(error != .generationFailed("x"))
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("every error offers either a retry or a fallback, so none is a dead end")
    func noErrorIsADeadEnd() {
        let all: [AscendError] = [
            .noProfile, .taskNotPending("x"), .taskNotCompleted("x"), .noCompletionToUndo("x"),
            .notReversible("x"), .appleIntelligenceUnsupportedDevice, .appleIntelligenceDisabled,
            .appleIntelligenceModelNotReady, .unsupportedLanguage, .goalTooVague, .goalRefused,
            .contextWindowExceeded, .generationBusy, .generationRateLimited,
            .generationFailed("x"), .invalidRoadmap("x"),
        ]
        for error in all {
            #expect(!error.title.isEmpty, "\(error) had no title")
            #expect(error.errorDescription?.isEmpty == false, "\(error) had no message")
            #expect(!error.symbolName.isEmpty, "\(error) had no icon")
        }
        // The engine-state errors are the only ones the user cannot act on, and they are bugs
        // rather than conditions -- everything to do with generation must offer a way forward.
        let generationErrors: [AscendError] = [
            .appleIntelligenceUnsupportedDevice, .appleIntelligenceDisabled,
            .appleIntelligenceModelNotReady, .unsupportedLanguage, .goalRefused,
            .contextWindowExceeded, .generationBusy, .generationRateLimited,
            .generationFailed("x"), .invalidRoadmap("x"),
        ]
        for error in generationErrors {
            #expect(error.isRetryable || error.allowsTemplateFallback,
                    "\(error) is a dead end")
        }
    }

    @Test("the cadence-variety rule is actually in the prompt")
    func cadenceRuleIsPresent() {
        #expect(RoadmapInstructions.taskPlanner.contains("oneShot"))
        #expect(RoadmapInstructions.taskPlanner.contains("weekly"))
        #expect(RoadmapInstructions.taskPlanner.contains("MIX the cadences"))
    }
}

@Suite("Scorer false positives")
struct ScorerFalsePositiveTests {

    @Test("reusing the goal's own nouns is not an echo when the step names an amount")
    func topicNounsAreNotEchoes() {
        // The bug this pins: a goal of "Read 12 books" makes "read" and "book" appear in every
        // legitimate step, and the echo rule scored a perfectly good plan 10/100.
        let score = GenericnessScore.evaluate(
            GenericnessScoreTests.draft([
                GenericnessScoreTests.task("Read 20 pages of the current book", cadence: .daily),
                GenericnessScoreTests.task("Write 3 sentences on what the book argued", cadence: .daily),
                GenericnessScoreTests.task("Pick the next book in 10 minutes", cadence: .weekly),
            ]),
            goalText: "Read 12 books this year and remember what is in them")
        #expect(score.goalEchoes.isEmpty, "flagged: \(score.goalEchoes)")
        #expect(score.score >= 90, "scored \(score.score)")
    }

    @Test("reusing the goal's nouns with no amount is still an echo")
    func vagueRestatementIsStillCaught() {
        let score = GenericnessScore.evaluate(
            GenericnessScoreTests.draft([GenericnessScoreTests.task("Read books")]),
            goalText: "Read 12 books this year and remember what is in them")
        #expect(!score.goalEchoes.isEmpty)
    }
}
