import Foundation
import SwiftData
import AscendDomain

/// The game engine: XP, levels, HP, gold, streaks, bosses.
///
/// Everything it decides, it decides by asking a pure value type in `AscendDomain`
/// (`ProgressionCurve`, `XPFormula`, `DamageFormula`, `StreakCalculator`) and then writing the
/// answer to the store. It holds no balance constants of its own -- those all live in
/// `GameRules` -- so a balance change is a diff to one value and its pinned tests, never a
/// hunt through this file.
///
/// It returns *descriptions* of what happened (`CompletionOutcome`, `RolloverReport`) rather
/// than letting the UI read the models and work it out. That is why no SwiftUI file in this
/// project needs to know the XP formula, and why every effect below is assertable headlessly.
///
/// ## Isolation
///
/// `@MainActor`, and it must stay that way. `ModelContainer.mainContext` is main-actor
/// isolated, and `ModelContext`'s `Sendable` conformance is declared
/// `@available(*, unavailable)`, so a background context could not hand objects back here
/// anyway -- only a `PersistentIdentifier` can cross. See the note at the top of
/// `UserProfile.swift` for why the compiler will *not* catch a `@Model` escaping this actor.
///
/// ## Why the mutating methods are synchronous
///
/// `@MainActor` plus synchronous means no interleaving, which is the entire concurrency story
/// for this type. The moment `processDayRolloverIfNeeded()` becomes `async` -- say to show a
/// progress spinner -- two `.task { }` blocks and a `scenePhase` handler can suspend inside it
/// and double-apply a day of damage. `isRolling` guards the reentrant case that remains; do
/// not make these `async` to make them feel responsive. They are already fast.
@MainActor
public final class GameManager: GameEngine {

    private let context: ModelContext
    private let rules: GameRules
    private let dateProvider: DateProviding
    private let calendar: Calendar

    /// Reentrancy guard for rollover. Not a lock -- on the main actor with synchronous methods
    /// there is nothing to lock against -- but `processDayRolloverIfNeeded` is called from app
    /// lifecycle events that genuinely do fire twice.
    private var isRolling = false

    /// The production initialiser.
    ///
    /// Takes the *container* rather than a context on purpose: handed a context, a caller can
    /// pass one that is not the context the views read from, and then writes land somewhere
    /// `@Query` never observes. Deriving `mainContext` here makes that mistake unavailable.
    public convenience init(container: ModelContainer,
                rules: GameRules = .standard,
                dateProvider: DateProviding = SystemDateProvider(),
                calendar: Calendar = .current) {
        self.init(context: container.mainContext,
                  rules: rules,
                  dateProvider: dateProvider,
                  calendar: calendar)
    }

    /// For tests and previews that want a throwaway context.
    public init(context: ModelContext,
                rules: GameRules = .standard,
                dateProvider: DateProviding = SystemDateProvider(),
                calendar: Calendar = .current) {
        self.context = context
        self.rules = rules
        self.dateProvider = dateProvider
        self.calendar = calendar
        // Autosave off, because every mutation here is a multi-object transaction. With
        // autosave on, a throw halfway through leaves half the change committed and SwiftData
        // offers no implicit rollback; `context.transaction { }` gives us all-or-nothing.
        context.autosaveEnabled = false
    }

    // MARK: - Completing a quest task

    public func complete(_ task: QuestTask) throws -> CompletionOutcome {
        guard task.state == .pending else {
            throw AscendError.taskNotPending(task.title)
        }
        let profile = try requireProfile()

        var outcome: CompletionOutcome!
        var unlocked: String?
        try context.transaction {
            outcome = try award(
                title: task.title,
                sourceKind: .task,
                sourceID: task.uuid,
                domain: task.domain,
                difficulty: task.difficulty,
                cadence: task.cadence,
                profile: profile
            )
            task.state = .completed
            task.completedAt = dateProvider.now
            if let milestone = task.milestone, milestone.isComplete {
                milestone.status = .completed
                unlocked = unlockNextMilestone(after: milestone)
            }
        }
        return outcome.unlocking(unlocked)
    }

    public func complete(_ habit: Habit) throws -> CompletionOutcome {
        let profile = try requireProfile()
        let streaks = streakCalculator(for: profile)
        let today = streaks.gameDayKey(for: dateProvider.now)

        // A daily habit is completable once per game day. Without this, tapping twice pays
        // twice and the streak multiplier compounds against itself.
        if habit.cadence == .daily,
           try completedDayKeys(forSourceID: habit.uuid).contains(today) {
            throw AscendError.taskNotPending(habit.title)
        }

        var outcome: CompletionOutcome!
        try context.transaction {
            outcome = try award(
                title: habit.title,
                sourceKind: .habit,
                sourceID: habit.uuid,
                domain: habit.domain,
                difficulty: habit.difficulty,
                cadence: habit.cadence,
                profile: profile
            )
            habit.lastCompletedAt = dateProvider.now
            habit.currentStreak = outcome.streak
            habit.bestStreak = max(habit.bestStreak, outcome.streak)
        }
        return outcome
    }

    /// The single place XP, gold, HP and boss damage are granted.
    ///
    /// Both `complete` overloads route through here so a task and a habit cannot drift apart
    /// in how they are paid -- which they did in every earlier sketch of this engine.
    private func award(title: String,
                       sourceKind: CompletionSourceKind,
                       sourceID: UUID,
                       domain: SkillDomain,
                       difficulty: TaskDifficulty,
                       cadence: TaskCadence,
                       profile: UserProfile) throws -> CompletionOutcome {
        let now = dateProvider.now
        let streaks = streakCalculator(for: profile)

        // The streak *before* this completion, plus this one if it builds a streak. Computed
        // from the ledger, so it survives the task being edited or regenerated.
        let priorKeys = try completedDayKeys(forSourceID: sourceID)
        let todayKey = streaks.gameDayKey(for: now)
        let streak = cadence.buildsStreak
            ? streaks.streak(endingOn: now, completedDayKeys: priorKeys.union([todayKey]))
            : 0

        let xp = rules.xp.xp(difficulty: difficulty, cadence: cadence, streak: max(0, streak - 1))
        let multiplier = rules.xp.streakMultiplier(forStreak: cadence.buildsStreak ? max(0, streak - 1) : 0)

        // MARK: skill tree
        guard let tree = profile.skillTree(for: domain) else {
            throw AscendError.noProfile
        }
        let skillLevelBefore = rules.skillCurve.level(forTotalXP: tree.totalXP)
        tree.totalXP += xp
        let skillLevelAfter = rules.skillCurve.level(forTotalXP: tree.totalXP)

        // MARK: character pool
        let charLevelBefore = rules.characterCurve.level(forTotalXP: profile.totalXP)
        profile.totalXP += xp
        let charLevelAfter = rules.characterCurve.level(forTotalXP: profile.totalXP)

        var levelUps: [LevelUpEvent] = []
        if skillLevelAfter > skillLevelBefore {
            for level in (skillLevelBefore + 1)...skillLevelAfter {
                levelUps.append(LevelUpEvent(scope: .skill(domain), newLevel: level))
            }
        }
        if charLevelAfter > charLevelBefore {
            for level in (charLevelBefore + 1)...charLevelAfter {
                levelUps.append(LevelUpEvent(scope: .character, newLevel: level))
            }
        }

        // MARK: gold
        let goldBefore = profile.gold
        profile.gold = goldBefore + rules.goldPerCompletion
        let appliedGold = profile.gold - goldBefore

        // MARK: healing
        //
        // Recorded as the *clamped* delta, not the nominal one. Heal 2 HP while already at
        // 50/50, record +2, and undoing the completion drops the user to 48 -- losing HP they
        // never gained. The applied difference is the only number safe to reverse.
        let maxHP = rules.maxHP(forCharacterLevel: charLevelAfter)
        let hpBefore = profile.currentHP
        if try isEverythingDueComplete(for: profile, on: now) {
            profile.currentHP = min(maxHP, hpBefore + rules.healAmount(forMaxHP: maxHP))
        } else {
            profile.currentHP = min(maxHP, hpBefore)
        }
        let appliedHP = profile.currentHP - hpBefore

        // MARK: boss
        var appliedBossDamage = 0
        var bossName: String?
        var bossDefeated = false
        var bossID: UUID?
        if let boss = profile.activeBosses.first(where: { $0.accepts(domain: domain) }) {
            let before = boss.currentHP
            boss.currentHP = max(0, before - rules.bossDamage(forXP: xp))
            appliedBossDamage = before - boss.currentHP
            bossName = boss.name
            bossID = boss.uuid
            if boss.currentHP == 0 {
                boss.isDefeated = true
                boss.defeatedAt = now
                bossDefeated = true
            }
        }

        let log = CompletionLog(occurredAt: now,
                               gameDayKey: todayKey,
                               sourceKind: sourceKind,
                               sourceID: sourceID,
                               title: title,
                               domain: domain,
                               xpAwarded: xp,
                               characterXPAwarded: xp,
                               goldAwarded: appliedGold,
                               hpDelta: appliedHP,
                               bossDamage: appliedBossDamage,
                               bossID: bossID,
                               streakAtCompletion: streak)
        context.insert(log)

        return CompletionOutcome(
            title: title,
            awards: [XPAward(domain: domain,
                             baseXP: difficulty.baseXP,
                             streakMultiplier: multiplier,
                             cadenceWeight: cadence.xpWeight,
                             total: xp)],
            characterXP: xp,
            levelUps: levelUps,
            streak: streak,
            goldAwarded: appliedGold,
            hpDelta: appliedHP,
            bossDamage: appliedBossDamage,
            bossName: bossName,
            bossDefeated: bossDefeated
        )
    }


    /// Opens the next locked tier of the same goal, in `orderIndex` order.
    ///
    /// Returns its title so the UI can celebrate the unlock. Side-quests inserted by a
    /// recalibration carry negative indices, so they are already ahead of everything and are
    /// unlocked on insertion rather than here.
    private func unlockNextMilestone(after milestone: Milestone) -> String? {
        guard let goal = milestone.goal else { return nil }
        guard let next = goal.orderedMilestones.first(where: {
            $0.orderIndex > milestone.orderIndex && $0.status == .locked
        }) else { return nil }
        next.status = .active
        return next.title
    }

    // MARK: - Undo

    /// Reverses a completion using the amounts the ledger says were applied.
    ///
    /// Recording the amounts is necessary but not sufficient -- there are states a completion
    /// simply cannot be lifted out of, and pretending otherwise corrupts the profile quietly:
    ///
    /// - **A rollover has run since.** The streak that produced the multiplier has already
    ///   been consumed by miss calculations; unwinding the XP now leaves the profile
    ///   inconsistent with a day that is already closed.
    /// - **The completion killed a boss.** Loot was granted and may have been spent, so
    ///   un-defeating is not expressible as a subtraction.
    ///
    /// Both throw `AscendError.notReversible` rather than half-applying.
    public func uncomplete(_ task: QuestTask) throws {
        guard task.state == .completed else {
            throw AscendError.taskNotCompleted(task.title)
        }
        let profile = try requireProfile()
        guard let log = try latestLog(forSourceID: task.uuid) else {
            throw AscendError.noCompletionToUndo(task.title)
        }
        if let lastRollover = profile.lastRolloverDate, log.occurredAt < lastRollover {
            throw AscendError.notReversible(
                "\"\(task.title)\" was completed before a day rolled over, so its streak has already been counted."
            )
        }
        if log.bossDamage > 0, log.bossIDString != nil, wasBossDefeated(by: log, profile: profile) {
            throw AscendError.notReversible(
                "Completing \"\(task.title)\" defeated \(log.title.isEmpty ? "a boss" : (bossName(for: log, profile: profile) ?? "a boss")), which can't be undone."
            )
        }

        try context.transaction {
            reverse(log, on: profile)
            log.wasUndone = true
            task.state = .pending
            task.completedAt = nil
            if let milestone = task.milestone, milestone.status == .completed {
                milestone.status = .active
            }
        }
    }

    /// Subtracts exactly what was applied, clamping so a reversal can never push a value
    /// below zero or HP above its maximum.
    private func reverse(_ log: CompletionLog, on profile: UserProfile) {
        if let tree = profile.skillTree(for: log.domain) {
            tree.totalXP = max(0, tree.totalXP - log.xpAwarded)
        }
        profile.totalXP = max(0, profile.totalXP - log.characterXPAwarded)
        profile.gold = max(0, profile.gold - log.goldAwarded)

        let level = rules.characterCurve.level(forTotalXP: profile.totalXP)
        let maxHP = rules.maxHP(forCharacterLevel: level)
        profile.currentHP = min(maxHP, max(0, profile.currentHP - log.hpDelta))

        if log.bossDamage > 0,
           let bossIDString = log.bossIDString,
           let boss = profile.bosses.first(where: { $0.uuid.uuidString == bossIDString }) {
            boss.currentHP = min(boss.maxHP, boss.currentHP + log.bossDamage)
            if boss.currentHP > 0 {
                boss.isDefeated = false
                boss.defeatedAt = nil
            }
        }
    }

    private func wasBossDefeated(by log: CompletionLog, profile: UserProfile) -> Bool {
        guard let idString = log.bossIDString,
              let boss = profile.bosses.first(where: { $0.uuid.uuidString == idString })
        else { return false }
        return boss.isDefeated
    }

    private func bossName(for log: CompletionLog, profile: UserProfile) -> String? {
        guard let idString = log.bossIDString else { return nil }
        return profile.bosses.first { $0.uuid.uuidString == idString }?.name
    }

    // MARK: - Reads

    public func snapshot() throws -> CharacterSnapshot {
        let profile = try requireProfile()
        let progress = rules.characterCurve.progress(forTotalXP: profile.totalXP)
        let skills = SkillDomain.allCases.map { domain in
            let xp = profile.skillTree(for: domain)?.totalXP ?? 0
            return SkillSnapshot(domain: domain,
                                 totalXP: xp,
                                 progress: rules.skillCurve.progress(forTotalXP: xp))
        }
        return CharacterSnapshot(displayName: profile.displayName,
                                 progress: progress,
                                 currentHP: profile.currentHP,
                                 maxHP: rules.maxHP(forCharacterLevel: progress.level),
                                 gold: profile.gold,
                                 skills: skills,
                                 defeatCount: profile.defeatCount)
    }

    public func streak(forHabit habit: Habit) throws -> Int {
        let profile = try requireProfile()
        let streaks = streakCalculator(for: profile)
        return streaks.streak(endingOn: dateProvider.now,
                              completedDayKeys: try completedDayKeys(forSourceID: habit.uuid))
    }

    // MARK: - Internals shared with the rollover extension

    func requireProfile() throws -> UserProfile {
        guard let profile = try DefaultSeed.existingProfile(in: context) else {
            throw AscendError.noProfile
        }
        return profile
    }

    func streakCalculator(for profile: UserProfile) -> StreakCalculator {
        StreakCalculator(calendar: calendar, dayStartHour: profile.dayStartHour)
    }

    var gameRules: GameRules { rules }
    var clock: DateProviding { dateProvider }
    var store: ModelContext { context }
    var rollInProgress: Bool {
        get { isRolling }
        set { isRolling = newValue }
    }

    /// Frozen day keys of every completion of one source that has not been undone.
    func completedDayKeys(forSourceID id: UUID) throws -> Set<Int> {
        let idString = id.uuidString
        let descriptor = FetchDescriptor<CompletionLog>(
            predicate: #Predicate { $0.sourceIDString == idString && $0.wasUndone == false }
        )
        return Set(try context.fetch(descriptor).map(\.gameDayKey))
    }

    func latestLog(forSourceID id: UUID) throws -> CompletionLog? {
        let idString = id.uuidString
        var descriptor = FetchDescriptor<CompletionLog>(
            predicate: #Predicate { $0.sourceIDString == idString && $0.wasUndone == false },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Whether everything due today is done -- the condition for the daily heal.
    func isEverythingDueComplete(for profile: UserProfile, on date: Date) throws -> Bool {
        let streaks = streakCalculator(for: profile)
        let todayKey = streaks.gameDayKey(for: date)

        let pendingTasks = profile.goals
            .filter { $0.status == .active }
            .flatMap(\.allTasks)
            .filter { $0.cadence.accruesMissDamage && $0.state == .pending }
        guard pendingTasks.isEmpty else { return false }

        for habit in profile.habits where habit.accruesMissDamage {
            if !(try completedDayKeys(forSourceID: habit.uuid)).contains(todayKey) { return false }
        }
        // Nothing due at all is not an achievement, so it does not heal.
        let hasAnythingDue = !profile.habits.filter(\.accruesMissDamage).isEmpty
            || !profile.goals.filter { $0.status == .active }.flatMap(\.allTasks).isEmpty
        return hasAnythingDue
    }
}
