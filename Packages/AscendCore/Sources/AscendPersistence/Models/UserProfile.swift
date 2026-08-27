import Foundation
import SwiftData
import AscendDomain

// MARK: - A warning that belongs at the top of this file
//
// `@Model` ATTACHES `Sendable`. Check it yourself:
//   grep -n "public macro Model" $(xcrun --sdk iphoneos --show-sdk-path)/System/Library/\
//     Frameworks/SwiftData.framework/Modules/SwiftData.swiftmodule/*.swiftinterface
//
// It compiles because the macro rewrites every persisted `var` into a computed property over
// `_$backingData`, leaving no mutable stored state for the concurrency checker to object to.
//
// The consequence is the important part: `Task.detached { print(task.title) }` compiles
// clean and then reads torn state or trips CoreData's thread assertions at runtime. On the
// single most dangerous mistake available in this layer, the compiler is silent.
//
// So it is a rule instead: **a @Model instance never leaves the main actor.** To hand one to
// another isolation domain, pass its `PersistentIdentifier` -- which is genuinely Sendable --
// and re-fetch with `context.model(for:)`. `ModelContext` itself is safe by comparison: its
// `Sendable` conformance is marked `@available(*, unavailable)`, so passing a context across
// an isolation boundary is a real compile error with a real message.
//
// This is also why the value types the engine returns (CompletionOutcome, RolloverReport,
// CharacterSnapshot) carry copied primitives and never a model reference: their Sendable
// conformance would otherwise be a lie the compiler happily accepts.

/// The character. A single row; `DefaultSeed` fetches-or-creates it.
///
/// `totalXP` here is the **character** pool and is its own source of truth, not a cached sum
/// of the skill trees. That looks like duplication and is not: defeat has to be able to cost
/// you a character level without confiscating skill mastery you earned weeks ago, and two
/// independent pools express that directly. Summing the trees instead would mean a defeat had
/// to claw XP back out of six trees proportionally, which is both fiddly and cruel.
///
/// `level` is deliberately absent -- it is derived from `totalXP` through `ProgressionCurve`.
/// Storing it would let the two drift, and would turn a balance change into a data migration.
@Model
public final class UserProfile {
    #Index<UserProfile>([\.createdAt])

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
    public var displayName: String = ""
    public var currentHP: Int = 50
    public var gold: Int = 0
    public var totalXP: Int = 0
    public var createdAt: Date = Date()
    /// Last instant a rollover was resolved. The idempotency guard for `processDayRolloverIfNeeded`.
    public var lastRolloverDate: Date?
    /// Hour a game day begins, 0-23. 4 by default: finishing at 01:30 still counts as yesterday.
    public var dayStartHour: Int = 4
    public var defeatCount: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \SkillTree.profile)
    public var skills: [SkillTree] = []

    @Relationship(deleteRule: .cascade, inverse: \Goal.profile)
    public var goals: [Goal] = []

    @Relationship(deleteRule: .cascade, inverse: \Habit.profile)
    public var habits: [Habit] = []

    @Relationship(deleteRule: .cascade, inverse: \Boss.profile)
    public var bosses: [Boss] = []

    public init(displayName: String = "",
                currentHP: Int = 50,
                gold: Int = 0,
                totalXP: Int = 0,
                createdAt: Date = Date(),
                dayStartHour: Int = 4) {
        self.uuid = UUID()
        self.displayName = displayName
        self.currentHP = currentHP
        self.gold = gold
        self.totalXP = totalXP
        self.createdAt = createdAt
        self.dayStartHour = dayStartHour
    }

    public func skillTree(for domain: SkillDomain) -> SkillTree? {
        skills.first { $0.domainRaw == domain.rawValue }
    }

    /// Bosses still worth fighting, hardest-hit first so the UI shows the one in progress.
    public var activeBosses: [Boss] {
        bosses.filter { !$0.isDefeated }.sorted { $0.currentHP < $1.currentHP }
    }
}
