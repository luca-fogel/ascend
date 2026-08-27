import Foundation
import AscendDomain

/// Measures how *generic* a generated roadmap is.
///
/// "The roadmap feels generic" is the single most common complaint about an AI planner, and it
/// is unfalsifiable as stated -- so this turns it into numbers a prompt edit can move.
///
/// The signals are the ones that actually distinguish a useful plan from filler:
///
/// - **Filler phrases.** A small model under-specified will reach for "research the topic",
///   "stay motivated", "track your progress". None of these tell anyone what to do today.
/// - **Concreteness.** A good step contains a quantity or a named artefact: "Run 3km",
///   "Write 500 words", "Cook two meals from the plan". A vague one does not.
/// - **Goal echo.** Restating the goal as a step ("Work on getting fit") is the laziest
///   possible output and a strong signal the prompt was too thin.
/// - **Variety.** All-medium difficulty and all-daily cadence means the model is not thinking
///   about the work, just filling a shape.
public struct GenericnessScore: Sendable, Equatable {
    public var fillerHits: [String] = []
    public var concreteSteps: Int = 0
    public var totalSteps: Int = 0
    public var goalEchoes: [String] = []
    public var distinctDifficulties: Int = 0
    public var distinctCadences: Int = 0
    public var averageTitleWords: Double = 0

    /// Fraction of steps carrying a number or a named artefact. Higher is better.
    public var concreteness: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(concreteSteps) / Double(totalSteps)
    }

    /// 0 (generic) to 100 (specific and varied). A single number to watch across prompt edits.
    public var score: Int {
        guard totalSteps > 0 else { return 0 }
        var value = 100.0
        value -= Double(fillerHits.count) * 12
        value -= Double(goalEchoes.count) * 15
        value -= (1 - concreteness) * 40
        if distinctDifficulties < 2 { value -= 10 }
        if distinctCadences < 2 { value -= 8 }
        return max(0, min(100, Int(value.rounded())))
    }

    /// Phrases that carry no instruction. Matched case-insensitively as substrings.
    public static let fillerPhrases = [
        "research", "stay motivated", "stay consistent", "be consistent",
        "track your progress", "monitor your progress", "review your progress",
        "make a plan", "create a plan", "set goals", "set a goal", "get started",
        "learn the basics", "familiarise yourself", "familiarize yourself",
        "as needed", "if possible", "try to", "continue to", "keep going",
        "various", "etc.", "and more", "explore different", "look into",
    ]

    public static func evaluate(_ draft: RoadmapDraft, goalText: String) -> GenericnessScore {
        var result = GenericnessScore()
        let goalWords = Set(
            goalText.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .filter { $0.count > 3 }
                .map(String.init)
        )

        var difficulties = Set<TaskDifficulty>()
        var cadences = Set<TaskCadence>()
        var titleWordCounts: [Int] = []

        let allText = ([draft.title, draft.summary]
            + draft.milestones.flatMap { [$0.title, $0.detail] }
            + draft.milestones.flatMap(\.tasks).flatMap { [$0.title, $0.detail] })
            .joined(separator: " \u{2022} ")
            .lowercased()

        for phrase in fillerPhrases where allText.contains(phrase) {
            result.fillerHits.append(phrase)
        }

        for task in draft.milestones.flatMap(\.tasks) {
            result.totalSteps += 1
            difficulties.insert(task.difficulty)
            cadences.insert(task.cadence)
            let words = task.title.split(whereSeparator: \.isWhitespace)
            titleWordCounts.append(words.count)

            if isConcrete(task.title) { result.concreteSteps += 1 }

            // A step whose title is mostly the goal's own words *and* names no amount is the
            // goal restated.
            //
            // The concreteness condition is not optional. Without it this flagged legitimate
            // steps for any goal whose subject nouns must appear in every step: "Read 12 books"
            // marked "Read 20 pages of a book" as an echo, and scored an otherwise excellent
            // plan 10/100. Reusing the goal's nouns is the topic; reusing them while adding no
            // quantity is the failure.
            let taskWords = Set(words.map { $0.lowercased().filter(\.isLetter) }.filter { $0.count > 3 })
            if !taskWords.isEmpty, !goalWords.isEmpty, !isConcrete(task.title) {
                let overlap = Double(taskWords.intersection(goalWords).count) / Double(taskWords.count)
                if overlap > 0.6 { result.goalEchoes.append(task.title) }
            }
        }

        result.distinctDifficulties = difficulties.count
        result.distinctCadences = cadences.count
        result.averageTitleWords = titleWordCounts.isEmpty
            ? 0
            : Double(titleWordCounts.reduce(0, +)) / Double(titleWordCounts.count)
        return result
    }

    /// A step is concrete if it names a quantity, a duration, or a countable artefact.
    public static func isConcrete(_ title: String) -> Bool {
        if title.contains(where: \.isNumber) { return true }
        let units = ["minute", "hour", "page", "chapter", "rep", "set", "km", "mile",
                     "word", "session", "meal", "day", "week", "line", "exercise",
                     "once", "twice", "daily", "one ", "two ", "three ", "five ", "ten "]
        let lower = title.lowercased()
        return units.contains { lower.contains($0) }
    }
}
