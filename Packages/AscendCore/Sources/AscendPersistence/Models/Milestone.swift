import Foundation
import SwiftData
import AscendDomain

/// One tier of a roadmap. Owns the daily steps that satisfy it.
@Model
public final class Milestone {
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
    /// Explicit ordering -- SwiftData relationship arrays are unordered.
    public var orderIndex: Int = 0
    public var statusRaw: String = MilestoneStatus.locked.rawValue
    /// A recalibration side-quest rather than part of the original plan.
    public var isSideQuest: Bool = false
    public var createdAt: Date = Date()

    public var goal: Goal?

    @Relationship(deleteRule: .cascade, inverse: \QuestTask.milestone)
    public var tasks: [QuestTask] = []

    public init(title: String,
                detail: String = "",
                orderIndex: Int = 0,
                status: MilestoneStatus = .locked,
                isSideQuest: Bool = false,
                createdAt: Date = Date()) {
        self.uuid = UUID()
        self.title = title
        self.detail = detail
        self.orderIndex = orderIndex
        self.statusRaw = status.rawValue
        self.isSideQuest = isSideQuest
        self.createdAt = createdAt
    }

    public var status: MilestoneStatus {
        get { MilestoneStatus(rawValue: statusRaw) ?? .locked }
        set { statusRaw = newValue.rawValue }
    }

    public var orderedTasks: [QuestTask] {
        tasks.sorted { $0.orderIndex < $1.orderIndex }
    }

    public var isComplete: Bool {
        !tasks.isEmpty && tasks.allSatisfy { $0.stateRaw == TaskState.completed.rawValue }
    }
}
