import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence

/// Today's work: quest steps, habits, and the way back when a goal has drifted.
struct TodayView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<QuestTask> { $0.stateRaw == "pending" },
           sort: \QuestTask.orderIndex)
    private var pendingTasks: [QuestTask]

    @Query(filter: #Predicate<Habit> { $0.isActive }, sort: \Habit.createdAt)
    private var habits: [Habit]

    @State private var viewModel = TodayViewModel()
    /// Also settable at launch, so the creation form can be screenshotted:
    /// `simctl launch <device> com.foggylulu.Ascend -sheet goal`. Same reasoning as the `-tab`
    /// argument in RootView -- a form nobody can look at is a form that drifts.
    @State private var isCreatingGoal = ProcessInfo.processInfo.arguments.contains("goal")
        && ProcessInfo.processInfo.arguments.contains("-sheet")
    @State private var isAddingHabitAtLaunch = ProcessInfo.processInfo.arguments.contains("habit")
        && ProcessInfo.processInfo.arguments.contains("-sheet")
    @State private var editingHabit: Habit?
    @State private var isAddingHabit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New goal", systemImage: "map") { isCreatingGoal = true }
                        Button("New habit", systemImage: "repeat") { isAddingHabit = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
            }
            .sheet(isPresented: $isCreatingGoal) { GoalCreationView() }
            .sheet(isPresented: $isAddingHabit) { HabitEditorView(habit: nil) }
            .sheet(item: $editingHabit) { HabitEditorView(habit: $0) }
            .task {
                if isAddingHabitAtLaunch { isAddingHabit = true }
                checkDrift()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let outcome = viewModel.lastOutcome {
                OutcomeBanner(outcome: outcome,
                              onUndo: viewModel.canUndo ? undo : nil,
                              onDismiss: viewModel.dismissOutcome)
            }
            if let error = viewModel.error {
                ErrorCard(error: error, onRetry: nil, onUseTemplate: nil)
            }
            if let accepted = viewModel.recalibrationAccepted {
                AcceptedSideQuestCard(title: accepted)
            }
            driftSection

            if pendingTasks.isEmpty && habits.isEmpty {
                EmptyStateCard { isCreatingGoal = true }
            } else {
                if !pendingTasks.isEmpty {
                    LabeledGroup("Quest steps") {
                        ForEach(pendingTasks) { task in
                            CompletionRow(title: task.title, detail: task.detail,
                                          domain: task.domain, difficulty: task.difficulty,
                                          streak: nil) { complete(task) }
                        }
                    }
                }
                habitSection
            }
        }
    }

    @ViewBuilder
    private var habitSection: some View {
        if habits.isEmpty {
            EmptyStateCard(symbolName: "repeat",
                           title: "No habits yet",
                           message: "Habits are the daily routines that aren't part of any goal \u{2014} the things you want to do because of who they make you.",
                           actionTitle: "Add a habit",
                           onCreate: { isAddingHabit = true })
        } else {
            LabeledGroup("Habits") {
                ForEach(habits) { habit in
                    CompletionRow(title: habit.title, detail: habit.detail,
                                  domain: habit.domain, difficulty: habit.difficulty,
                                  streak: habit.currentStreak) { complete(habit) }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editingHabit = habit }
                            Button("Retire", systemImage: "archivebox") {
                                try? Roster.retire(habit, context: modelContext)
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var driftSection: some View {
        if let goal = viewModel.driftingGoal {
            if let patch = viewModel.patch {
                WayBackCard(patch: patch,
                            onAccept: { viewModel.acceptWayBack(context: modelContext) },
                            onDecline: viewModel.declineWayBack)
            } else {
                DriftCard(goalTitle: goal.title,
                          missedDays: viewModel.driftingDays,
                          isWorking: viewModel.isRecalibrating,
                          onAsk: askForWayBack)
            }
        }
    }

    // MARK: - Actions

    private func complete(_ task: QuestTask) {
        guard let container else { return }
        withAnimation(Theme.Motion.celebratory) {
            viewModel.complete(task, using: container.engine)
        }
        if let outcome = viewModel.lastOutcome { Haptics.forOutcome(outcome) }
        else if viewModel.error != nil { Haptics.setback() }
        checkDrift()
    }

    private func complete(_ habit: Habit) {
        guard let container else { return }
        withAnimation(Theme.Motion.celebratory) {
            viewModel.complete(habit, using: container.engine)
        }
        if let outcome = viewModel.lastOutcome { Haptics.forOutcome(outcome) }
        else if viewModel.error != nil { Haptics.setback() }
    }

    private func undo() {
        guard let container else { return }
        withAnimation(Theme.Motion.standard) {
            viewModel.undoLast(using: container.engine)
        }
    }

    private func askForWayBack() {
        guard let container else { return }
        Task { await viewModel.requestWayBack(using: container.roadmapService) }
    }

    private func checkDrift() {
        guard let profile = try? DefaultSeed.profile(in: modelContext) else { return }
        viewModel.checkForDrift(profile: profile, context: modelContext,
                                now: Date(), calendar: .current)
    }
}

#Preview {
    TodayView().appContainer(.preview())
}
