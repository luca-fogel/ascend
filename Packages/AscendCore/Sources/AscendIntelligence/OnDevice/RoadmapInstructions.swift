import Foundation
import AscendDomain

/// Prompts live with the provider that sends them, never with the caller.
///
/// Same rule as solvr-ai's `SolutionProvider`: a view model asks for a roadmap and has no
/// opinion about how it is requested, so swapping the backend cannot change a prompt and
/// editing a prompt cannot ripple into the UI layer.
///
/// ## These prompts were tuned against measurements, not taste
///
/// `swift run ascend-eval` scores real on-device output with `GenericnessScore`. The first
/// version of this file scored a mean of 53/100, and the harness said exactly why:
///
/// - Step titles averaged 3.3 words with no quantities: "Draft lyrics", "Pick a tune",
///   "Record a song". Concreteness fell to 7% on one goal.
/// - Milestones were counters rather than capabilities: "record one song", "record two songs",
///   "record three songs".
/// - Tier three re-planned tier one nearly verbatim, because stage two could not see the rest
///   of the plan (now fixed by `PlanContext`).
/// - Milestone detail restated the milestone: "At this point you should have recorded two
///   songs. This means that your creativity is evolving."
///
/// Every rule below targets one of those. Changing a rule without re-running the harness is
/// how a prompt drifts back to filler.
enum RoadmapInstructions {

    /// Phrases the model reaches for when it has nothing specific to say. Naming them
    /// explicitly works better on a small model than asking for "specificity" in the abstract.
    static let bannedPhrases = "research, learn the basics, familiarise yourself, stay motivated, "
        + "stay consistent, track your progress, review your progress, make a plan, set goals, "
        + "get started, explore different, look into, as needed, various, etc."

    static let milestonePlanner = """
        You turn an ambitious personal goal into a plan of milestones.

        A milestone is a checkpoint the person can recognise reaching. Write each one so that
        someone could look at their week and say yes or no.

        Rules:
        - Each milestone must be a DIFFERENT KIND of achievement, not a bigger number of the
          same one. Repeating one activity with the count going up is a counter, not a plan.
          Progress from capability to capability: first rough attempt, first finished artefact,
          first time under a real constraint, first time in front of other people.
        - Order them so each one is only possible because the previous one happened.
        - Scale the count to the time available. A short horizon gets three large milestones,
          not seven thin ones. Never pad to reach a number.
        - The detail field states HOW SOMEONE KNOWS this milestone is done -- the observable
          test. Do not restate the title and do not describe how the person will feel.
        - Be specific to this goal. Never use these phrases: \(bannedPhrases)
        """

    static let taskPlanner = """
        You turn one milestone of a plan into the concrete steps that achieve it.

        Rules:
        - EVERY step title must state an amount: a digit followed by a unit that fits this
          goal's own subject matter -- minutes, pages, reps, sets, words, lines, items, takes,
          sessions. Turn every bare verb phrase into a measured one: not "draft the outline"
          but "draft the outline in 25 minutes"; not "practise scales" but "practise 4 scales".
          Choose units from the goal in front of you and never from another domain.
        - A step is one sitting's work and must fit inside the stated daily time budget. Size
          the amounts to that budget: 20 minutes a day cannot absorb a two-hour step.
        - Do not repeat or rephrase any step already planned for an earlier milestone. If the
          obvious step is taken, go one level more specific.
        - MIX the cadences. At least one step must be 'oneShot' (a one-time setup, purchase or
          decision that unblocks the rest) and at least one must be 'weekly' (a review, a
          measurement, or a longer session that cannot fit in a normal day). Everything else
          is 'daily'. A batch where every step is 'daily' is wrong and must be revised before
          you answer.
        - Vary difficulty honestly. Not everything is medium.
        - The detail field adds information the title cannot hold: a method, a constraint, or
          how to tell the step was done well. Never restate the title.
        - Be specific to this milestone. Never use these phrases: \(bannedPhrases)
        """

    static let recalibrator = """
        You help someone restart a plan after they have missed several days.

        Rules:
        - Treat missed days as ordinary. Do not lecture, apologise, moralise, or mention
          discipline, willpower or motivation.
        - The catch-up steps must be visibly smaller than the plan they rejoin: five or ten
          minutes of real work, with the amount stated in the title.
        - Be specific to this goal. Never use these phrases: \(bannedPhrases)
        """

    static func milestonePrompt(for request: RoadmapRequest) -> String {
        var lines = [
            "Goal: \(request.goalText)",
            "Time available: \(request.minutesPerDay) minutes a day, \(request.horizonWeeks) weeks "
                + "(about \(request.horizonWeeks * 7) days, \(request.horizonWeeks * request.minutesPerDay * 7 / 60) hours in total).",
        ]
        if !request.preferredDomains.isEmpty {
            lines.append("Areas to develop: "
                         + request.preferredDomains.map(\.title).joined(separator: ", ") + ".")
        }
        if let extra = request.extraContext, !extra.isEmpty {
            lines.append("Extra context: \(extra)")
        }
        return lines.joined(separator: "\n")
    }

    static func taskPrompt(for milestone: MilestoneDraft,
                           in request: RoadmapRequest,
                           context: PlanContext) -> String {
        var lines = [
            "Overall goal: \(request.goalText)",
            "Daily time budget: \(request.minutesPerDay) minutes. Every step must fit in one such sitting.",
            "",
            "Break down ONLY this milestone:",
            "  \(milestone.title)",
            "  Done when: \(milestone.detail)",
        ]
        // Showing the arc is what stops a middle tier from re-planning the first one.
        if context.milestoneTitles.count > 1 {
            lines.append("")
            lines.append("It is milestone \(context.currentIndex + 1) of \(context.milestoneTitles.count) in this plan:")
            for (index, title) in context.milestoneTitles.enumerated() {
                let marker = index == context.currentIndex ? ">" : " "
                lines.append("  \(marker) \(index + 1). \(title)")
            }
            lines.append("Do not do the work of the other milestones.")
        }
        if !context.plannedStepTitles.isEmpty {
            lines.append("")
            lines.append("Already planned in earlier milestones -- do not repeat or rephrase these:")
            // Capped: the context window is small and the most recent tier is the one most at
            // risk of being duplicated.
            for title in context.plannedStepTitles.suffix(12) {
                lines.append("  - \(title)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func recalibrationPrompt(for request: RecalibrationRequest) -> String {
        """
        Goal: \(request.goalTitle)
        What finishing looks like: \(request.goalSummary)
        Days missed in a row: \(request.missedDays)
        Daily time budget: \(request.minutesPerDay) minutes.
        Still ahead: \(request.remainingMilestoneTitles.joined(separator: "; "))
        """
    }
}
