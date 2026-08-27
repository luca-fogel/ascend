import Foundation
import SwiftData
import Testing
import AscendDomain
@testable import AscendPersistence

/// A whole game in memory, with a clock the test controls.
///
/// Every persistence test builds one of these rather than sharing state: an in-memory
/// container costs microseconds, and a shared one turns an ordering bug in one test into a
/// mystery failure in another.
struct TestWorld {
    let container: ModelContainer
    let context: ModelContext
    let profile: UserProfile
    let clock: MutableDateProvider
    let engine: GameManager
    let calendar: Calendar

    /// Anchored to a fixed instant in a fixed zone. A test that depends on "now" or on the
    /// machine's timezone fails in CI for reasons unrelated to the code.
    static let anchor: Date = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/London")!
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.date(from: "2026-03-10 09:00")!
    }()

    init(rules: GameRules = .standard, start: Date = TestWorld.anchor) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        calendar.locale = Locale(identifier: "en_GB")
        self.calendar = calendar

        self.container = try AscendStore.inMemoryContainer()
        self.context = ModelContext(container)
        self.clock = MutableDateProvider(start)
        self.profile = try DefaultSeed.profile(in: context)
        self.engine = GameManager(context: context,
                                  rules: rules,
                                  dateProvider: clock,
                                  calendar: calendar)
        // Seeding uses `Date()` for createdAt; pin it to the anchor so elapsed-day maths in
        // rollover tests starts from a known point rather than from real wall-clock time.
        profile.createdAt = start
        profile.lastRolloverDate = start
        try context.save()
    }

    /// A one-milestone goal whose tasks the tests complete.
    @discardableResult
    func addGoal(taskCount: Int = 3,
                 difficulty: TaskDifficulty = .medium,
                 cadence: TaskCadence = .daily,
                 domain: SkillDomain = .fitness,
                 status: GoalStatus = .active) throws -> Goal {
        let tasks = (0..<taskCount).map { index in
            TaskDraft(title: "Step \(index + 1)",
                      detail: "",
                      difficulty: difficulty,
                      cadence: cadence,
                      domain: domain,
                      orderIndex: index)
        }
        let draft = RoadmapDraft(title: "Get stronger",
                                 summary: "A test plan",
                                 primaryDomain: domain,
                                 milestones: [MilestoneDraft(title: "Foundations",
                                                             detail: "First tier",
                                                             orderIndex: 0,
                                                             tasks: tasks)])
        let goal = try RoadmapImporter.importDraft(
            draft,
            request: RoadmapRequest(goalText: "Get stronger", horizonWeeks: 4),
            generatorIdentifier: "test/fixture",
            into: profile,
            context: context,
            now: clock.now,
            calendar: calendar
        )
        goal.status = status
        try context.save()
        return goal
    }

    @discardableResult
    func addHabit(title: String = "Read for 20 minutes",
                  difficulty: TaskDifficulty = .easy,
                  domain: SkillDomain = .intellect) throws -> Habit {
        let habit = Habit(title: title,
                          difficulty: difficulty,
                          cadence: .daily,
                          domain: domain,
                          createdAt: clock.now)
        context.insert(habit)
        habit.profile = profile
        try context.save()
        return habit
    }

    func tasks(of goal: Goal) -> [QuestTask] {
        goal.orderedMilestones.flatMap(\.orderedTasks)
    }

    func skillXP(_ domain: SkillDomain) -> Int {
        profile.skillTree(for: domain)?.totalXP ?? 0
    }

    func logs() throws -> [CompletionLog] {
        try context.fetch(FetchDescriptor<CompletionLog>(
            sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
        ))
    }

    var streaks: StreakCalculator {
        StreakCalculator(calendar: calendar, dayStartHour: profile.dayStartHour)
    }
}
