import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence

struct GoalListView: View {
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if goals.isEmpty {
                        NoGoalsCard { isCreating = true }
                    } else {
                        ForEach(goals) { goal in
                            NavigationLink {
                                GoalDetailView(goal: goal)
                            } label: {
                                GoalCard(goal: goal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New goal")
                }
            }
            .sheet(isPresented: $isCreating) { GoalCreationView() }
        }
    }
}

private struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label(goal.primaryDomain.title, systemImage: goal.primaryDomain.symbolName)
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(goal.primaryDomain.color)
                Spacer()
                Text(goal.status.rawValue.capitalized)
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }
            Text(goal.title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.leading)

            StatBar(fraction: goal.completionFraction, tint: goal.primaryDomain.color, height: 6)

            HStack {
                let done = goal.orderedMilestones.filter { $0.status == .completed }.count
                Text("\(done) of \(goal.milestones.count) milestones")
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                Text("\(Int(goal.completionFraction * 100))%")
                    .font(Theme.Fonts.number(12, .semibold))
                    .foregroundStyle(goal.primaryDomain.color)
            }
        }
        .card()
    }
}

private struct NoGoalsCard: View {
    let onCreate: @MainActor () -> Void

    var body: some View {
        EmptyStateCard(
            symbolName: "map",
            title: "No goals yet",
            message: "Name something ambitious and Ascend will break it into milestones and daily steps — planned on your iPhone, not in the cloud.",
            actionTitle: "Create a goal",
            onCreate: onCreate)
    }
}

#Preview {
    GoalListView().appContainer(.preview())
}
