import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence

/// The one screen where an ambition becomes a plan.
struct GoalCreationView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = GoalCreationViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                phaseContent
                    .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle("New goal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .editing:
            editor
        case .planning(let stage):
            GenerationProgressView(stage: stage, goalText: viewModel.goalText)
        case .review(let draft):
            RoadmapPreview(draft: draft,
                           generator: viewModel.generatorIdentifier,
                           onAccept: save,
                           onRegenerate: generate,
                           onEdit: viewModel.backToEditing)
        case .saving:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xxl)
        case .saved(let title):
            SavedCard(title: title) { dismiss() }
        case .failed(let error):
            failure(error)
        }
    }

    @ViewBuilder
    private func failure(_ error: AscendError) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ErrorCard(error: error,
                      onRetry: error.isRetryable ? generate : nil,
                      onUseTemplate: error.allowsTemplateFallback ? useTemplate : nil)
            Button("Change the goal", action: viewModel.backToEditing)
                .font(Theme.Fonts.bodyEmphasis)
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: Theme.Spacing.lg) {
            LabelledField(
                label: "What do you want to achieve?",
                placeholder: "Get into Equinox shape",
                help: viewModel.canGenerate || viewModel.goalText.isEmpty
                    ? "Be specific about what finishing looks like. The more concrete the goal, the better the plan."
                    // Real-time feedback (p162) rather than a button that is simply dead with no
                    // explanation of why.
                    : "A few more words and I can plan this \u{2014} say what finishing looks like.",
                lineLimit: 3...6,
                text: $viewModel.goalText)
                .card()

            VStack(alignment: .leading, spacing: Theme.Spacing.base) {
                stepper("Horizon", value: $viewModel.horizonWeeks,
                        range: 1...52, unit: viewModel.horizonWeeks == 1 ? "week" : "weeks")
                Divider().overlay(Theme.Colors.hairline)
                stepper("Time per day", value: $viewModel.minutesPerDay,
                        range: 5...240, step: 5, unit: "min")
            }
            .card()

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Which areas does this build?")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
                Text("Optional. Steers which skill trees earn the XP.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                domainPicker
            }
            .card()

            PrimaryButton(title: "Generate roadmap",
                          isEnabled: viewModel.canGenerate,
                          action: generate)

            Text("Planned entirely on your iPhone. Nothing is sent anywhere.")
                .font(Theme.Fonts.micro)
                .foregroundStyle(Theme.Colors.tertiaryText)
                .frame(maxWidth: .infinity)
        }
    }

    private func stepper(_ title: String,
                         value: Binding<Int>,
                         range: ClosedRange<Int>,
                         step: Int = 1,
                         unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.bodyEmphasis)
                    .foregroundStyle(Theme.Colors.primaryText)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .font(Theme.Fonts.number(15, .semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    private var domainPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3),
                  spacing: Theme.Spacing.sm) {
            ForEach(SkillDomain.allCases) { domain in
                let isOn = viewModel.preferredDomains.contains(domain)
                Button {
                    withAnimation(Theme.Motion.quick) {
                        if isOn { viewModel.preferredDomains.remove(domain) }
                        else { viewModel.preferredDomains.insert(domain) }
                    }
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: domain.symbolName).font(.system(size: 15))
                        Text(domain.title).font(Theme.Fonts.micro)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .foregroundStyle(isOn ? domain.color : Theme.Colors.secondaryText)
                    .background(
                        (isOn ? domain.color.opacity(0.16) : Theme.Colors.surfaceRaised),
                        in: .rect(cornerRadius: Theme.Radii.sm)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radii.sm)
                            .strokeBorder(isOn ? domain.color.opacity(0.5) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func generate() {
        guard let container else { return }
        Task { await viewModel.generate(using: container.roadmapService) }
    }

    private func useTemplate() {
        guard let container else { return }
        Task { await viewModel.generateFromTemplate(using: container.templateService) }
    }

    private func save() {
        guard let profile = try? DefaultSeed.profile(in: modelContext) else { return }
        viewModel.save(into: profile, context: modelContext)
    }
}

#Preview {
    GoalCreationView().appContainer(.preview())
}
