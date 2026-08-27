import SwiftUI
import AscendDomain

/// The approval gate.
///
/// A generated roadmap is a suggestion, not a verdict, so the user sees it before anything is
/// written to the store. Regenerating is free and framed as such -- the alternative is a
/// history full of eight-week plans nobody wanted.
struct RoadmapPreview: View {
    let draft: RoadmapDraft
    let generator: String
    let onAccept: @MainActor () -> Void
    let onRegenerate: @MainActor () -> Void
    let onEdit: @MainActor () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label(draft.primaryDomain.title, systemImage: draft.primaryDomain.symbolName)
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(draft.primaryDomain.color)
                    Spacer()
                    // Which planner wrote this. A template plan should never be mistaken for a
                    // generated one.
                    Text(generator == "template/v1" ? "From a template" : "Planned on device")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
                Text(draft.title)
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.primaryText)
                if !draft.summary.isEmpty {
                    Text(draft.summary)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Array(draft.milestones.enumerated()), id: \.offset) { index, milestone in
                    MilestoneDraftRow(index: index,
                                      milestone: milestone,
                                      domain: draft.primaryDomain,
                                      isFirst: index == 0)
                }
                // Says why only tier one has steps, so an empty tier reads as intentional
                // rather than as a generation that gave up half way.
                if draft.milestones.count > 1 {
                    Text("Steps for the later milestones are written when you unlock them, so you only ever see what you're actually working on.")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .padding(.top, Theme.Spacing.xs)
                }
            }
            .card()

            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: "Start this roadmap", action: onAccept)

                HStack(spacing: Theme.Spacing.base) {
                    Button("Generate again", action: onRegenerate)
                    Button("Change the goal", action: onEdit)
                }
                .font(Theme.Fonts.bodyEmphasis)
            }
        }
    }
}

private struct MilestoneDraftRow: View {
    let index: Int
    let milestone: MilestoneDraft
    let domain: SkillDomain
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Text("\(index + 1)")
                    .font(Theme.Fonts.number(13))
                    .foregroundStyle(isFirst ? domain.color : Theme.Colors.tertiaryText)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().fill(isFirst ? domain.color.opacity(0.18) : Theme.Colors.surfaceRaised)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(Theme.Fonts.bodyEmphasis)
                        .foregroundStyle(Theme.Colors.primaryText)
                    if !milestone.detail.isEmpty {
                        Text(milestone.detail)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !milestone.tasks.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(Array(milestone.tasks.enumerated()), id: \.offset) { _, task in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "circle")
                                .font(.system(size: 9))
                                .foregroundStyle(task.domain.color)
                            Text(task.title)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Spacer(minLength: 0)
                            Text(task.cadence == .daily ? "daily" : task.cadence == .weekly ? "weekly" : "once")
                                .font(Theme.Fonts.micro)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                }
                .padding(.leading, 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SavedCard: View {
    let title: String
    let onDone: @MainActor () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.base) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.success)
            Text("\u{201C}\(title)\u{201D} is live")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.primaryText)
            Text("Its first steps are waiting on Today.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            PrimaryButton(title: "Done", action: onDone)
                .padding(.top, Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Spacing.xxl)
    }
}
