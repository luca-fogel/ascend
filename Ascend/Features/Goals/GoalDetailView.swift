import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence

/// A roadmap, tier by tier.
///
/// This is where lazy stage-two generation lands: the tier the user is actually on has its
/// steps written on first open, so they wait a few seconds for one tier instead of a minute for
/// all six at creation time.
///
/// The generation trigger is deliberately **one `.task` on the whole screen**, not one per
/// tier. Per-tier tasks fire concurrently, and because the on-device model allows a single
/// session at a time, all but the first would fail with `generationBusy` -- a race that looks
/// like a flaky model rather than the scheduling mistake it is.
struct GoalDetailView: View {
    let goal: Goal

    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = GoalDetailViewModel()

    var body: some View {
        ScrollView {
            content
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(AscendBackground())
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: pendingTierID) { await fillNextTier() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Theme.Spacing.lg) {
            summary
            if let error = viewModel.error {
                ErrorCard(error: error,
                          onRetry: error.isRetryable ? retry : nil,
                          onUseTemplate: error.allowsTemplateFallback ? useTemplate : nil)
            }
            ForEach(goal.orderedMilestones) { milestone in
                MilestoneSection(milestone: milestone,
                                 domain: goal.primaryDomain,
                                 isGenerating: viewModel.isGenerating(milestone))
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !goal.detail.isEmpty {
                Text(goal.detail)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            StatBar(fraction: goal.completionFraction, tint: goal.primaryDomain.color, height: 6)
            HStack {
                Text("\(goal.horizonWeeks) weeks \u{00B7} \(goal.minutesPerDay) min/day")
                Spacer()
                Text(goal.generatorIdentifier == "template/v1" ? "From a template" : "Planned on device")
            }
            .font(Theme.Fonts.micro)
            .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .card()
    }

    // MARK: - Lazy generation

    /// The one tier that wants steps right now, or `nil`. Keying `.task` on this means the work
    /// re-runs exactly when a tier unlocks, and not otherwise.
    private var pendingTierID: UUID? {
        nextTier?.uuid
    }

    private var nextTier: Milestone? {
        goal.orderedMilestones.first { $0.status != .locked && $0.tasks.isEmpty }
    }

    private func fillNextTier() async {
        guard let tier = nextTier, let container else { return }
        await viewModel.generateSteps(for: tier,
                                      in: goal,
                                      using: container.roadmapService,
                                      context: modelContext)
    }

    private func retry() {
        Task { await fillNextTier() }
    }

    private func useTemplate() {
        guard let tier = nextTier, let container else { return }
        Task {
            await viewModel.generateSteps(for: tier,
                                          in: goal,
                                          using: container.templateService,
                                          context: modelContext)
        }
    }
}

private struct MilestoneSection: View {
    let milestone: Milestone
    let domain: SkillDomain
    let isGenerating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header
            if milestone.status == .locked {
                Text("Unlocks when the previous milestone is done.")
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            } else if isGenerating {
                Text("Writing the steps for this milestone\u{2026}")
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            } else {
                if !milestone.detail.isEmpty {
                    Text(milestone.detail)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(milestone.orderedTasks) { task in
                    TaskLine(task: task)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .opacity(milestone.status == .locked ? 0.55 : 1)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: symbolName)
                .font(.system(size: 15))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(milestone.title)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(milestone.status == .locked
                                     ? Theme.Colors.tertiaryText : Theme.Colors.primaryText)
                if milestone.isSideQuest {
                    Text("Side-quest")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.gold)
                }
            }
            Spacer()
            if isGenerating { ProgressView().controlSize(.small) }
        }
    }

    private var symbolName: String {
        switch milestone.status {
        case .locked:    "lock.fill"
        case .active:    "circle.dashed"
        case .completed: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch milestone.status {
        case .locked:    Theme.Colors.tertiaryText
        case .active:    domain.color
        case .completed: Theme.Colors.success
        }
    }
}

private struct TaskLine: View {
    let task: QuestTask

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: symbolName)
                .font(.system(size: 12))
                .foregroundStyle(tint)
            Text(task.title)
                .font(Theme.Fonts.caption)
                .foregroundStyle(task.state == .completed
                                 ? Theme.Colors.tertiaryText : Theme.Colors.secondaryText)
                .strikethrough(task.state == .completed, color: Theme.Colors.tertiaryText)
            Spacer(minLength: 0)
            Text(task.difficulty.title)
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
    }

    private var symbolName: String {
        switch task.state {
        case .completed: "checkmark.circle.fill"
        case .missed:    "exclamationmark.circle"
        default:         "circle"
        }
    }

    private var tint: Color {
        switch task.state {
        case .completed: Theme.Colors.success
        case .missed:    Theme.Colors.hp
        default:         task.domain.color
        }
    }
}
