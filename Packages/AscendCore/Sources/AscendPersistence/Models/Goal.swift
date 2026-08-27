import Foundation
import SwiftData
import AscendDomain

/// A lofty ambition plus the roadmap generated from it.
@Model
public final class Goal {
    /// A stable UUID for this row.
    ///
    /// Named `uuid`, **not** `id`, and that is load-bearing. `PersistentModel` already conforms
    /// to `Identifiable` and supplies `var id: PersistentIdentifier`; declaring a stored `id`
    /// too gives the type two `id` members and makes the `Identifiable` associated type
    /// ambiguous. The symptom is not a clear error -- `ForEach(models)` fails to type-check and
    /// the compiler reports "failed to produce diagnostic for expression". Keeping the two
    /// identities separately named keeps SwiftUI identity (`id`) and our own durable reference
    /// (`uuid`, used by CompletionLog's ledger link) distinct and intentional.
    public var uuid: UUID = UUID()
    public var title: String = ""
    public var detail: String = ""
    public var createdAt: Date = Date()
    public var targetDate: Date?
    public var statusRaw: String = GoalStatus.draft.rawValue
    public var horizonWeeks: Int = 8
    public var minutesPerDay: Int = 30
    public var primaryDomainRaw: String = SkillDomain.intellect.rawValue

    /// Which provider produced this roadmap, e.g. `"apple-on-device/guided"` or
    /// `"template/v1"`. Recorded so a strange plan can be traced to its author.
    public var generatorIdentifier: String = ""

    public var profile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \Milestone.goal)
    public var milestones: [Milestone] = []

    public init(title: String,
                detail: String = "",
                horizonWeeks: Int = 8,
                minutesPerDay: Int = 30,
                primaryDomain: SkillDomain = .intellect,
                status: GoalStatus = .draft,
                generatorIdentifier: String = "",
                createdAt: Date = Date(),
                targetDate: Date? = nil) {
        self.uuid = UUID()
        self.title = title
        self.detail = detail
        self.horizonWeeks = horizonWeeks
        self.minutesPerDay = minutesPerDay
        self.primaryDomainRaw = primaryDomain.rawValue
        self.statusRaw = status.rawValue
        self.generatorIdentifier = generatorIdentifier
        self.createdAt = createdAt
        self.targetDate = targetDate
    }

    public var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    public var primaryDomain: SkillDomain {
        get { SkillDomain(rawValue: primaryDomainRaw) ?? .intellect }
        set { primaryDomainRaw = newValue.rawValue }
    }

    /// SwiftData does not guarantee the order of a to-many relationship, so order is carried
    /// explicitly by `orderIndex` and applied here. Never read `milestones` positionally.
    public var orderedMilestones: [Milestone] {
        milestones.sorted { $0.orderIndex < $1.orderIndex }
    }

    public var allTasks: [QuestTask] { milestones.flatMap(\.tasks) }

    public var completionFraction: Double {
        let tasks = allTasks
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { $0.stateRaw == TaskState.completed.rawValue }.count
        return Double(done) / Double(tasks.count)
    }
}
