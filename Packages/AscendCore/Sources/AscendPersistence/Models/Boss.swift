import Foundation
import SwiftData
import AscendDomain

/// A named adversary standing in for a real failure mode.
///
/// Damage arrives as a side effect of completing real work -- there is no "attack" button,
/// because the point is that doing the task *is* the attack.
@Model
public final class Boss {
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
    public var name: String = ""
    public var kindRaw: String = BossKind.procrastination.rawValue
    public var maxHP: Int = 400
    public var currentHP: Int = 400
    public var deadline: Date?
    public var isDefeated: Bool = false
    public var defeatedAt: Date?
    /// Optional affinity: a boss that only takes damage from one domain. `nil` takes all.
    public var domainRaw: String?
    public var createdAt: Date = Date()

    public var profile: UserProfile?

    public init(kind: BossKind,
                name: String? = nil,
                maxHP: Int? = nil,
                domain: SkillDomain? = nil,
                deadline: Date? = nil,
                createdAt: Date = Date()) {
        self.uuid = UUID()
        self.kindRaw = kind.rawValue
        self.name = name ?? kind.displayName
        let hp = maxHP ?? kind.baseHP
        self.maxHP = hp
        self.currentHP = hp
        self.domainRaw = domain?.rawValue
        self.deadline = deadline
        self.createdAt = createdAt
    }

    public var kind: BossKind {
        get { BossKind(rawValue: kindRaw) ?? .procrastination }
        set { kindRaw = newValue.rawValue }
    }

    public var domain: SkillDomain? {
        get { domainRaw.flatMap(SkillDomain.init(rawValue:)) }
        set { domainRaw = newValue?.rawValue }
    }

    public var hpFraction: Double {
        guard maxHP > 0 else { return 0 }
        return min(1, max(0, Double(currentHP) / Double(maxHP)))
    }

    public func accepts(domain incoming: SkillDomain) -> Bool {
        guard let required = domain else { return true }
        return required == incoming
    }
}
