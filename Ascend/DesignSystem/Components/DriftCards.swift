import SwiftUI
import AscendDomain

/// The moment the brief calls "dynamic AI re-routing".
///
/// The framing matters as much as the mechanic. A tracker that says "you failed, streak lost"
/// is why people delete trackers. This says the plan was wrong for the week you had, and
/// offers to bend it -- which is the only honest reading, since the roadmap was a guess made
/// before the week happened.
struct DriftCard: View {
    let goalTitle: String
    let missedDays: Int
    let isWorking: Bool
    let onAsk: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(Theme.Colors.gold)
                Text("\(missedDays) days off the path")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            Text("\u{201C}\(goalTitle)\u{201D} has been waiting. The plan was written before this week happened \u{2014} I can bend it into a smaller way back in.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if isWorking {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView().controlSize(.small)
                    Text("Working out a way back\u{2026}")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            } else {
                PrimaryButton(title: "Find me a way back", ramp: Palette.gold, action: onAsk)
            }
        }
        .card()
    }
}

/// The generated side-quest, before it is committed.
struct WayBackCard: View {
    let patch: RoadmapPatch
    let onAccept: @MainActor () -> Void
    let onDecline: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.Colors.gold)
                Text("A side-quest back")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            Text(patch.rationale)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let quest = patch.sideQuest {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(quest.title)
                        .font(Theme.Fonts.bodyEmphasis)
                        .foregroundStyle(Theme.Colors.primaryText)
                    ForEach(Array(quest.tasks.enumerated()), id: \.offset) { _, task in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "circle")
                                .font(.system(size: 9))
                                .foregroundStyle(task.domain.color)
                            Text(task.title)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Spacer(minLength: 0)
                            Text(task.difficulty.title)
                                .font(Theme.Fonts.micro)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surfaceRaised, in: .rect(cornerRadius: Theme.Radii.md))
            }

            // Primary on the right: around 90% of people are right-handed, so the right side is
            // the easier thumb reach on a phone (p134). "Add the side-quest" rather than "Add
            // it", because button text should say exactly what will happen (p246).
            HStack(spacing: Theme.Spacing.md) {
                TertiaryButton(title: "Not now", action: onDecline)
                Spacer()
                Button("Add the side-quest", action: onAccept)
                    .buttonStyle(PressableButtonStyle())
                    .textStyle(TypeSize.caption, .semibold)
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.vertical, Theme.Spacing.md)
                    .foregroundStyle(Theme.Colors.onFill(Palette.gold))
                    .background(Color(Palette.buttonFill(Palette.gold)),
                                in: .rect(cornerRadius: Theme.Radii.sm))
            }
        }
        .card()
    }
}

struct AcceptedSideQuestCard: View {
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.Colors.success)
            Text("\u{201C}\(title)\u{201D} added \u{2014} its steps are in the goal now.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: Theme.Spacing.md)
    }
}
