import Foundation
import SwiftData
import AscendDomain

/// Creating and retiring the things the user owns directly: habits and bosses.
///
/// Goals arrive through `RoadmapImporter` because they are generated. These are authored by
/// hand, so they get their own door -- but the same rules apply: every insert goes through a
/// transaction, and nothing is created without being attached to the profile.
@MainActor
public enum Roster {

    // MARK: - Habits

    /// Adds a habit. Titles are deduplicated case-insensitively.
    ///
    /// Duplicate habits are worse than they look: each one accrues its own miss damage at
    /// rollover, so "Read" twice means being charged twice a day for one intention.
    @discardableResult
    public static func addHabit(title: String,
                                detail: String = "",
                                difficulty: TaskDifficulty,
                                cadence: TaskCadence,
                                domain: SkillDomain,
                                to profile: UserProfile,
                                context: ModelContext,
                                now: Date = Date()) throws -> Habit {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw AscendError.invalidRoadmap("A habit needs a name.")
        }
        if let existing = profile.habits.first(where: {
            $0.title.compare(clean, options: .caseInsensitive) == .orderedSame
        }) {
            return existing
        }

        var created: Habit!
        try context.transaction {
            let habit = Habit(title: clean,
                              detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                              difficulty: difficulty,
                              cadence: cadence,
                              domain: domain,
                              createdAt: now)
            context.insert(habit)
            habit.profile = profile
            created = habit
        }
        return created
    }

    public static func update(_ habit: Habit,
                              title: String,
                              detail: String,
                              difficulty: TaskDifficulty,
                              cadence: TaskCadence,
                              domain: SkillDomain,
                              context: ModelContext) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw AscendError.invalidRoadmap("A habit needs a name.")
        }
        try context.transaction {
            habit.title = clean
            habit.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.difficulty = difficulty
            habit.cadence = cadence
            habit.domain = domain
        }
    }

    /// Retires a habit without destroying history.
    ///
    /// Deactivating rather than deleting on purpose: the `CompletionLog` entries referencing it
    /// stay meaningful, the streak record survives, and it stops accruing miss damage
    /// immediately. Deleting is offered separately for a habit added by mistake.
    public static func retire(_ habit: Habit, context: ModelContext) throws {
        try context.transaction {
            habit.isActive = false
            habit.currentStreak = 0
        }
    }

    public static func reactivate(_ habit: Habit, context: ModelContext) throws {
        try context.transaction { habit.isActive = true }
    }

    public static func delete(_ habit: Habit, context: ModelContext) throws {
        try context.transaction { context.delete(habit) }
    }

    // MARK: - Bosses

    /// Which adversaries the user has not yet faced or beaten.
    public static func availableBossKinds(for profile: UserProfile) -> [BossKind] {
        let taken = Set(profile.bosses.map(\.kindRaw))
        return BossKind.allCases.filter { !taken.contains($0.rawValue) }
    }

    /// Brings a new boss into play.
    ///
    /// One at a time by default: `GameManager` routes damage to the first accepting active
    /// boss, so several undamaged bosses at once would look like nothing is happening to most
    /// of them.
    @discardableResult
    public static func summonBoss(_ kind: BossKind,
                                  domain: SkillDomain? = nil,
                                  deadline: Date? = nil,
                                  for profile: UserProfile,
                                  context: ModelContext,
                                  now: Date = Date()) throws -> Boss {
        if let existing = profile.bosses.first(where: { $0.kindRaw == kind.rawValue && !$0.isDefeated }) {
            return existing
        }
        var created: Boss!
        try context.transaction {
            let boss = Boss(kind: kind, domain: domain, deadline: deadline, createdAt: now)
            context.insert(boss)
            boss.profile = profile
            created = boss
        }
        return created
    }
}
