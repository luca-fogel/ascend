import Foundation

/// What the user asked for.
public struct RoadmapRequest: Sendable, Equatable, Hashable, Codable {
    public let goalText: String
    public let horizonWeeks: Int
    public let minutesPerDay: Int
    public let preferredDomains: [SkillDomain]
    public let extraContext: String?

    public init(goalText: String,
                horizonWeeks: Int = 8,
                minutesPerDay: Int = 30,
                preferredDomains: [SkillDomain] = [],
                extraContext: String? = nil) {
        self.goalText = goalText
        self.horizonWeeks = horizonWeeks
        self.minutesPerDay = minutesPerDay
        self.preferredDomains = preferredDomains
        self.extraContext = extraContext
    }
}

/// A model-authored roadmap, before it is allowed anywhere near the store.
///
/// These are plain `Sendable` structs on purpose. The `@Generable` types the on-device model
/// actually fills in live in `AI/Generable/` and are mapped onto these -- so the domain layer
/// stays free of FoundationModels, and every validator and mapper test runs without an
/// Apple Intelligence-capable machine.
public struct RoadmapDraft: Sendable, Equatable, Hashable, Codable {
    public var title: String
    public var summary: String
    public var primaryDomain: SkillDomain
    public var milestones: [MilestoneDraft]

    public init(title: String, summary: String, primaryDomain: SkillDomain, milestones: [MilestoneDraft]) {
        self.title = title
        self.summary = summary
        self.primaryDomain = primaryDomain
        self.milestones = milestones
    }
}

public struct MilestoneDraft: Sendable, Equatable, Hashable, Codable {
    public var title: String
    public var detail: String
    public var orderIndex: Int
    public var tasks: [TaskDraft]

    public init(title: String, detail: String, orderIndex: Int, tasks: [TaskDraft] = []) {
        self.title = title
        self.detail = detail
        self.orderIndex = orderIndex
        self.tasks = tasks
    }
}

public struct TaskDraft: Sendable, Equatable, Hashable, Codable {
    public var title: String
    public var detail: String
    public var difficulty: TaskDifficulty
    public var cadence: TaskCadence
    public var domain: SkillDomain
    public var orderIndex: Int

    public init(title: String,
                detail: String,
                difficulty: TaskDifficulty,
                cadence: TaskCadence,
                domain: SkillDomain,
                orderIndex: Int) {
        self.title = title
        self.detail = detail
        self.difficulty = difficulty
        self.cadence = cadence
        self.domain = domain
        self.orderIndex = orderIndex
    }
}

/// Input to a recalibration: the user fell off, and the roadmap has to bend.
public struct RecalibrationRequest: Sendable, Equatable, Hashable, Codable {
    public let goalTitle: String
    public let goalSummary: String
    public let missedDays: Int
    public let remainingMilestoneTitles: [String]
    public let minutesPerDay: Int

    public init(goalTitle: String,
                goalSummary: String,
                missedDays: Int,
                remainingMilestoneTitles: [String],
                minutesPerDay: Int) {
        self.goalTitle = goalTitle
        self.goalSummary = goalSummary
        self.missedDays = missedDays
        self.remainingMilestoneTitles = remainingMilestoneTitles
        self.minutesPerDay = minutesPerDay
    }
}

/// The result of a recalibration: an encouraging framing plus a bridge back onto the path.
public struct RoadmapPatch: Sendable, Equatable, Hashable, Codable {
    public var rationale: String
    public var sideQuest: MilestoneDraft?
    public var easedTaskTitles: [String]

    public init(rationale: String, sideQuest: MilestoneDraft?, easedTaskTitles: [String] = []) {
        self.rationale = rationale
        self.sideQuest = sideQuest
        self.easedTaskTitles = easedTaskTitles
    }
}

/// What the planner knows about the rest of the roadmap while detailing one tier.
///
/// Added because its absence was a visible quality bug, not a theoretical one: stage two was
/// called with a single milestone and no idea the others existed, so a twelve-week songwriting
/// plan produced "Write a song / Record a song / Upload song" in tier one and again, nearly
/// verbatim, in tier three. A planner cannot avoid repeating itself if it cannot see what it
/// has already said.
public struct PlanContext: Sendable, Equatable, Hashable, Codable {
    /// Every milestone title in order, so the model can see the arc it is part way through.
    public var milestoneTitles: [String]
    /// Which tier is being detailed, zero-based.
    public var currentIndex: Int
    /// Step titles already committed to earlier tiers, so they are not reinvented.
    public var plannedStepTitles: [String]

    public init(milestoneTitles: [String] = [],
                currentIndex: Int = 0,
                plannedStepTitles: [String] = []) {
        self.milestoneTitles = milestoneTitles
        self.currentIndex = currentIndex
        self.plannedStepTitles = plannedStepTitles
    }

    public static let none = PlanContext()

    /// Builds the context for one tier of a draft that is being filled in order.
    public static func forMilestone(at index: Int, in draft: RoadmapDraft) -> PlanContext {
        PlanContext(milestoneTitles: draft.milestones.map(\.title),
                    currentIndex: index,
                    plannedStepTitles: draft.milestones.prefix(index).flatMap(\.tasks).map(\.title))
    }
}
