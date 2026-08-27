import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence

/// Create or edit a habit.
///
/// Habits were the largest hole in the app: the engine has always supported them -- streaks,
/// miss damage, XP routing, the cached-streak repair -- and there was no way to make one.
struct HabitEditorView: View {
    /// `nil` creates; non-nil edits.
    let habit: Habit?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var difficulty: TaskDifficulty = .easy
    @State private var cadence: TaskCadence = .daily
    @State private var domain: SkillDomain = .discipline
    @State private var error: AscendError?

    private var isEditing: Bool { habit != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if let error { ErrorCard(error: error) }
                    nameCard
                    settingsCard
                    domainCard
                    saveButton
                    if isEditing { destructiveActions }
                }
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle(isEditing ? "Edit habit" : "New habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .onAppear(perform: load)
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
            LabelledField(
                label: "What will you do?",
                placeholder: "Read for 20 minutes",
                help: "Naming the amount makes it easier to know you did it \u{2014} \u{201C}read 20 minutes\u{201D} beats \u{201C}read more\u{201D}.",
                text: $title)
            LabelledField(
                label: "Detail",
                placeholder: "Anything worth remembering",
                isOptional: true,
                lineLimit: 1...3,
                text: $detail)
        }
        .card()
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
            Picker("How demanding", selection: $difficulty) {
                ForEach(TaskDifficulty.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("How often", selection: $cadence) {
                Text("Daily").tag(TaskCadence.daily)
                Text("Weekly").tag(TaskCadence.weekly)
            }
            .pickerStyle(.segmented)

            // Only daily habits are charged for at rollover, and saying so up front prevents
            // the app feeling arbitrary the first time HP drops.
            Text(cadence == .daily
                 ? "Daily habits build a streak, and cost HP on a day you skip."
                 : "Weekly habits pay more and are never charged for a missed day.")
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.tertiaryText)

            HStack {
                Text("Worth")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                // Shown from the real formula, so the number here cannot drift from the engine.
                Text("\(XPFormula.standard.xp(difficulty: difficulty, cadence: cadence, streak: 0)) XP")
                    .font(Theme.Fonts.number(14, .semibold))
                    .foregroundStyle(domain.color)
                if cadence.accruesMissDamage {
                    Text("\u{00B7} \(difficulty.missDamage) HP if missed")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.hp)
                }
            }
        }
        .card()
    }

    private var domainCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Which skill does it build?")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.primaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3),
                      spacing: Theme.Spacing.sm) {
                ForEach(SkillDomain.allCases) { candidate in
                    Button { domain = candidate } label: {
                        VStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: candidate.symbolName).font(.system(size: 15))
                            Text(candidate.title).font(Theme.Fonts.micro)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .foregroundStyle(domain == candidate ? candidate.color : Theme.Colors.secondaryText)
                        .background(domain == candidate ? candidate.color.opacity(0.16)
                                                        : Theme.Colors.surfaceRaised,
                                    in: .rect(cornerRadius: Theme.Radii.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var saveButton: some View {
        PrimaryButton(title: isEditing ? "Save changes" : "Add habit",
                      isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      action: save)
    }

    private var destructiveActions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let habit, habit.isActive {
                TertiaryButton(title: "Retire this habit", action: retire)
                Text("Keeps your streak record and stops it costing HP. Nothing is deleted.")
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                } else if habit != nil {
                Button("Bring it back", action: reactivate).font(Theme.Fonts.bodyEmphasis)
            }
            Button("Delete permanently", role: .destructive, action: deleteHabit)
                .font(Theme.Fonts.caption)
                .padding(.top, Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.base)
    }

    // MARK: - Actions

    private func load() {
        guard let habit else { return }
        title = habit.title
        detail = habit.detail
        difficulty = habit.difficulty
        cadence = habit.cadence
        domain = habit.domain
    }

    private func save() {
        do {
            if let habit {
                try Roster.update(habit, title: title, detail: detail, difficulty: difficulty,
                                  cadence: cadence, domain: domain, context: modelContext)
            } else {
                let profile = try DefaultSeed.profile(in: modelContext)
                try Roster.addHabit(title: title, detail: detail, difficulty: difficulty,
                                    cadence: cadence, domain: domain,
                                    to: profile, context: modelContext)
            }
            dismiss()
        } catch let error as AscendError {
            self.error = error
        } catch {
            self.error = .invalidRoadmap(error.localizedDescription)
        }
    }

    private func retire() {
        guard let habit else { return }
        try? Roster.retire(habit, context: modelContext)
        dismiss()
    }

    private func reactivate() {
        guard let habit else { return }
        try? Roster.reactivate(habit, context: modelContext)
        dismiss()
    }

    private func deleteHabit() {
        guard let habit else { return }
        try? Roster.delete(habit, context: modelContext)
        dismiss()
    }
}

#Preview {
    HabitEditorView(habit: nil).appContainer(.preview())
}
