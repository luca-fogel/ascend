import Foundation
import SwiftData
import AscendDomain

/// One XP pool per `SkillDomain`. Seeded once, six of them, never created ad hoc.
@Model
public final class SkillTree {
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

    /// Stored as the raw string, exposed as the enum.
    ///
    /// `#Predicate` over a custom enum has been unreliable, and a raw string keeps the store
    /// readable and migration-safe when a case is added or renamed. Every enum on every model
    /// in this package follows the same rule.
    public var domainRaw: String = SkillDomain.intellect.rawValue
    public var totalXP: Int = 0
    public var profile: UserProfile?

    public init(domain: SkillDomain, totalXP: Int = 0) {
        self.uuid = UUID()
        self.domainRaw = domain.rawValue
        self.totalXP = totalXP
    }

    public var domain: SkillDomain {
        get { SkillDomain(rawValue: domainRaw) ?? .intellect }
        set { domainRaw = newValue.rawValue }
    }
}
