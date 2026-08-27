import Foundation

/// The complete consequence of one completion.
///
/// The engine returns a *description* of what happened and the view layer animates from it.
/// That boundary is the reason no SwiftUI file ever needs to know the XP formula, and the
/// reason every one of these effects is assertable in a headless test.
public struct CompletionOutcome: Sendable, Equatable, Hashable {
    public let title: String
    public let awards: [XPAward]
    public let characterXP: Int
    public let levelUps: [LevelUpEvent]
    public let streak: Int
    public let goldAwarded: Int
    public let hpDelta: Int
    public let bossDamage: Int
    public let bossName: String?
    public let bossDefeated: Bool
    /// Set when this completion finished a milestone and opened the next one. The roadmap
    /// reveals itself a tier at a time, so this is the moment worth celebrating.
    public let unlockedMilestoneTitle: String?

    public init(title: String,
                awards: [XPAward],
                characterXP: Int,
                levelUps: [LevelUpEvent],
                streak: Int,
                goldAwarded: Int,
                hpDelta: Int,
                bossDamage: Int,
                bossName: String?,
                bossDefeated: Bool,
                unlockedMilestoneTitle: String? = nil) {
        self.title = title
        self.awards = awards
        self.characterXP = characterXP
        self.levelUps = levelUps
        self.streak = streak
        self.goldAwarded = goldAwarded
        self.hpDelta = hpDelta
        self.bossDamage = bossDamage
        self.bossName = bossName
        self.bossDefeated = bossDefeated
        self.unlockedMilestoneTitle = unlockedMilestoneTitle
    }

    public var totalXP: Int { awards.reduce(0) { $0 + $1.total } }
    public var didLevelUp: Bool { !levelUps.isEmpty }
}

/// What one game day of rollover did.
public struct RolloverReport: Sendable, Equatable, Hashable {
    public let gameDay: Date
    public let missedTitles: [String]
    public let rawDamage: Int
    public let appliedDamage: Int
    public let healed: Int
    public let brokenStreakTitles: [String]
    public let wasDefeated: Bool

    public init(gameDay: Date,
                missedTitles: [String],
                rawDamage: Int,
                appliedDamage: Int,
                healed: Int,
                brokenStreakTitles: [String],
                wasDefeated: Bool) {
        self.gameDay = gameDay
        self.missedTitles = missedTitles
        self.rawDamage = rawDamage
        self.appliedDamage = appliedDamage
        self.healed = healed
        self.brokenStreakTitles = brokenStreakTitles
        self.wasDefeated = wasDefeated
    }

    /// True when the cap actually bit. The UI says "damage reduced" instead of pretending
    /// the backlog was smaller than it was.
    public var wasDamageCapped: Bool { appliedDamage < rawDamage }
    public var missedCount: Int { missedTitles.count }
}

extension CompletionOutcome {
    /// Returns a copy carrying a milestone-unlock event.
    ///
    /// The unlock is discovered by the caller *after* `award` has run (it depends on the task's
    /// milestone becoming complete), and threading it back through `award`'s parameter list
    /// would make that function longer for no gain.
    public func unlocking(_ milestoneTitle: String?) -> CompletionOutcome {
        guard let milestoneTitle else { return self }
        return CompletionOutcome(title: title,
                                 awards: awards,
                                 characterXP: characterXP,
                                 levelUps: levelUps,
                                 streak: streak,
                                 goldAwarded: goldAwarded,
                                 hpDelta: hpDelta,
                                 bossDamage: bossDamage,
                                 bossName: bossName,
                                 bossDefeated: bossDefeated,
                                 unlockedMilestoneTitle: milestoneTitle)
    }
}
