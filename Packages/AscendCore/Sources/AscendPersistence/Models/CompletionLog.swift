import Foundation
import SwiftData
import AscendDomain

/// The append-only ledger of everything the engine has ever awarded.
///
/// Three jobs, and each one is a reason the engine can be trusted:
///
/// 1. **Exact undo.** A completion worth 46 XP because of a 15-day streak cannot be
///    recomputed once the streak has moved on. The amounts *actually applied* are recorded
///    here, so `uncomplete` subtracts a fact instead of re-deriving an estimate.
/// 2. **Streaks.** `StreakCalculator` replays these days, so a streak survives its task being
///    edited, rescheduled, or replaced by a recalibration.
/// 3. **Reconciliation.** The ledger sums to the XP the profile holds, which is what makes a
///    balance bug findable after the fact instead of merely suspected.
///
/// Two decisions worth knowing about:
///
/// **`sourceID` is a stored value, not a relationship.** A relationship would put this row
/// downstream of `Goal --cascade--> Milestone --cascade--> QuestTask`, so deleting one
/// abandoned goal would delete its completions -- silently rewriting a 40-day streak as a
/// 6-day one while leaving the profile's XP untouched, which destroys job 3. `title` is
/// denormalised for the same reason: a deleted task's ledger entry must still read sensibly.
/// Entries are marked `wasUndone`, never deleted; every streak query filters on it.
///
/// **`gameDayKey` is computed once, at write time.** Deriving the game day from `occurredAt`
/// on every read sounds equivalent and is not: flying from London to Tokyo re-buckets past
/// completions across the 04:00 boundary and retroactively splits one 40-day streak into two
/// 20-day ones. Freezing the day the completion happened in makes history immutable.
@Model
public final class CompletionLog {
    #Index<CompletionLog>([\.occurredAt], [\.sourceIDString], [\.gameDayKey])

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
    public var occurredAt: Date = Date()

    /// The game day this completion belongs to, as `yyyymmdd` in the timezone that was
    /// current when it happened. Frozen -- see the note above.
    public var gameDayKey: Int = 0

    public var sourceKindRaw: String = CompletionSourceKind.task.rawValue

    /// Stored as a string rather than `UUID`: this column is queried on every streak
    /// computation, and `#Predicate` comparison against `UUID` has been unreliable.
    public var sourceIDString: String = ""
    public var title: String = ""
    public var skillDomainRaw: String = SkillDomain.intellect.rawValue

    /// All four of these are the **clamped, applied** amounts, not the nominal ones.
    ///
    /// The distinction is a real bug if you get it wrong: heal 2 HP at 50/50, record the
    /// nominal +2, and undoing leaves the user at 48 having lost HP they never gained. Same
    /// shape for gold at a cap and XP at max level.
    public var xpAwarded: Int = 0
    public var characterXPAwarded: Int = 0
    public var goldAwarded: Int = 0
    public var hpDelta: Int = 0

    public var bossDamage: Int = 0
    public var bossIDString: String?
    public var streakAtCompletion: Int = 0
    public var wasUndone: Bool = false

    public init(occurredAt: Date,
                gameDayKey: Int,
                sourceKind: CompletionSourceKind,
                sourceID: UUID,
                title: String,
                domain: SkillDomain,
                xpAwarded: Int,
                characterXPAwarded: Int,
                goldAwarded: Int,
                hpDelta: Int,
                bossDamage: Int,
                bossID: UUID?,
                streakAtCompletion: Int) {
        self.uuid = UUID()
        self.occurredAt = occurredAt
        self.gameDayKey = gameDayKey
        self.sourceKindRaw = sourceKind.rawValue
        self.sourceIDString = sourceID.uuidString
        self.title = title
        self.skillDomainRaw = domain.rawValue
        self.xpAwarded = xpAwarded
        self.characterXPAwarded = characterXPAwarded
        self.goldAwarded = goldAwarded
        self.hpDelta = hpDelta
        self.bossDamage = bossDamage
        self.bossIDString = bossID?.uuidString
        self.streakAtCompletion = streakAtCompletion
    }

    public var sourceKind: CompletionSourceKind {
        get { CompletionSourceKind(rawValue: sourceKindRaw) ?? .task }
        set { sourceKindRaw = newValue.rawValue }
    }

    public var domain: SkillDomain {
        get { SkillDomain(rawValue: skillDomainRaw) ?? .intellect }
        set { skillDomainRaw = newValue.rawValue }
    }
}
