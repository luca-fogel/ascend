import Foundation
import SwiftData
import AscendDomain

/// A recurring routine that belongs to the user rather than to any one goal.
///
/// `currentStreak` and `bestStreak` are caches. The authority is `CompletionLog`, replayed by
/// `StreakCalculator`; `GameManager` writes these on every award and `GameManagerTests`
/// asserts the cached value equals the recomputed one, so the denormalisation is checked
/// rather than trusted. `bestStreak` genuinely needs storing -- it outlives any window of log
/// history we might later prune.
@Model
public final class Habit {
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
    public var difficultyRaw: String = TaskDifficulty.easy.rawValue
    public var cadenceRaw: String = TaskCadence.daily.rawValue
    public var skillDomainRaw: String = SkillDomain.discipline.rawValue
    public var currentStreak: Int = 0
    public var bestStreak: Int = 0
    public var lastCompletedAt: Date?
    public var isActive: Bool = true
    public var createdAt: Date = Date()

    public var profile: UserProfile?

    public init(title: String,
                detail: String = "",
                difficulty: TaskDifficulty = .easy,
                cadence: TaskCadence = .daily,
                domain: SkillDomain = .discipline,
                isActive: Bool = true,
                createdAt: Date = Date()) {
        self.uuid = UUID()
        self.title = title
        self.detail = detail
        self.difficultyRaw = difficulty.rawValue
        self.cadenceRaw = cadence.rawValue
        self.skillDomainRaw = domain.rawValue
        self.isActive = isActive
        self.createdAt = createdAt
    }

    public var difficulty: TaskDifficulty {
        get { TaskDifficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }

    public var cadence: TaskCadence {
        get { TaskCadence(rawValue: cadenceRaw) ?? .daily }
        set { cadenceRaw = newValue.rawValue }
    }

    public var domain: SkillDomain {
        get { SkillDomain(rawValue: skillDomainRaw) ?? .discipline }
        set { skillDomainRaw = newValue.rawValue }
    }

    public var accruesMissDamage: Bool { isActive && cadence.accruesMissDamage }
}
