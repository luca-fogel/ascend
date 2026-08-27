import Foundation
import SwiftData
import AscendDomain

/// A single actionable step.
///
/// Named `QuestTask` rather than `Task` on purpose: a `@Model final class Task` shadows
/// `_Concurrency.Task` for the entire module, so every `Task { await ... }` becomes a compile
/// error resolvable only by writing `_Concurrency.Task` at every async call site, forever.
/// The RPG framing makes the rename read as intent rather than a workaround.
@Model
public final class QuestTask {
    #Index<QuestTask>([\.stateRaw], [\.dueDate])

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
    public var difficultyRaw: String = TaskDifficulty.medium.rawValue
    public var cadenceRaw: String = TaskCadence.daily.rawValue
    public var stateRaw: String = TaskState.pending.rawValue
    public var skillDomainRaw: String = SkillDomain.intellect.rawValue
    public var dueDate: Date?
    public var completedAt: Date?
    public var isSideQuest: Bool = false
    public var createdAt: Date = Date()

    public var milestone: Milestone?

    public init(title: String,
                detail: String = "",
                orderIndex: Int = 0,
                difficulty: TaskDifficulty = .medium,
                cadence: TaskCadence = .daily,
                domain: SkillDomain = .intellect,
                state: TaskState = .pending,
                dueDate: Date? = nil,
                isSideQuest: Bool = false,
                createdAt: Date = Date()) {
        self.uuid = UUID()
        self.title = title
        self.detail = detail
        self.orderIndex = orderIndex
        self.difficultyRaw = difficulty.rawValue
        self.cadenceRaw = cadence.rawValue
        self.skillDomainRaw = domain.rawValue
        self.stateRaw = state.rawValue
        self.dueDate = dueDate
        self.isSideQuest = isSideQuest
        self.createdAt = createdAt
    }

    public var difficulty: TaskDifficulty {
        get { TaskDifficulty(rawValue: difficultyRaw) ?? .medium }
        set { difficultyRaw = newValue.rawValue }
    }

    public var cadence: TaskCadence {
        get { TaskCadence(rawValue: cadenceRaw) ?? .daily }
        set { cadenceRaw = newValue.rawValue }
    }

    public var state: TaskState {
        get { TaskState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    public var domain: SkillDomain {
        get { SkillDomain(rawValue: skillDomainRaw) ?? .intellect }
        set { skillDomainRaw = newValue.rawValue }
    }

    /// Whether a rollover may charge for not doing this. Only daily steps inside an active
    /// goal qualify -- a weekly step cannot be "missed today", and charging for a paused
    /// goal punishes the user for a choice the app offered them.
    public var accruesMissDamage: Bool {
        cadence.accruesMissDamage
            && state == .pending
            && milestone?.goal?.statusRaw == GoalStatus.active.rawValue
    }
}
