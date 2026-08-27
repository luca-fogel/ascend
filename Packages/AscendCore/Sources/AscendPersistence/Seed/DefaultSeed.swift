import Foundation
import SwiftData
import AscendDomain

/// First-launch state, created exactly once.
///
/// The duplicate-profile bug this is written to avoid is easy to hit and hard to notice: a
/// `@Query`-driven view and a `.task { }` on another screen both observe zero profiles and
/// both insert one, and the app ships with two characters whose XP silently diverges.
/// `.unique` would not save us either -- SwiftData implements it as an upsert, merging
/// attributes and *dropping the new object's relationships*, which loses skill trees rather
/// than reporting a conflict.
///
/// So seeding is fetch-then-insert inside a single transaction, and every caller routes
/// through here rather than constructing a `UserProfile` directly.
public enum DefaultSeed {

    @discardableResult
    public static func profile(in context: ModelContext) throws -> UserProfile {
        if let existing = try existingProfile(in: context) {
            try backfillSkillTrees(on: existing, in: context)
            return existing
        }

        var created: UserProfile!
        try context.transaction {
            // Re-check inside the transaction: the window between the check above and the
            // insert is exactly where the double-insert happens.
            if let existing = try existingProfile(in: context) {
                created = existing
            } else {
                let profile = UserProfile(displayName: "")
                context.insert(profile)
                for domain in SkillDomain.allCases {
                    let tree = SkillTree(domain: domain)
                    context.insert(tree)
                    tree.profile = profile
                }
                // One starting adversary. More are unlocked by play rather than dumped on the
                // user at launch.
                let boss = Boss(kind: .procrastination)
                context.insert(boss)
                boss.profile = profile
                created = profile
            }
        }
        return created
    }

    public static func existingProfile(in context: ModelContext) throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Adding a `SkillDomain` case in a later release must not leave existing users without
    /// its tree. Cheap to check, and the alternative is a crash-free but permanently missing
    /// skill that only reproduces on upgraded installs.
    private static func backfillSkillTrees(on profile: UserProfile, in context: ModelContext) throws {
        let present = Set(profile.skills.map(\.domainRaw))
        let missing = SkillDomain.allCases.filter { !present.contains($0.rawValue) }
        guard !missing.isEmpty else { return }
        try context.transaction {
            for domain in missing {
                let tree = SkillTree(domain: domain)
                context.insert(tree)
                tree.profile = profile
            }
        }
    }
}
