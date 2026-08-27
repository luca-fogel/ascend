import SwiftUI
import AscendDomain

/// Renders a `CompletionOutcome` and nothing else.
///
/// Every number here was decided by the engine and handed over as one value; the view has no
/// access to the XP formula.
///
/// **"Baseline, not center" (p118).** The title and the XP figure are different sizes on one
/// line. Centring them vertically offsets their baselines and reads as a misalignment, which is
/// most obvious exactly here, where the two sit close together. `.firstTextBaseline` uses the
/// reference line the eye is already following.
struct OutcomeBanner: View {
    let outcome: CompletionOutcome
    /// Absent for habits: the engine's reversal is written against a quest task's `.pending`
    /// state, and a habit has no equivalent to return to.
    var onUndo: (@MainActor () -> Void)?
    var onDismiss: (@MainActor () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(outcome.title)
                    .textStyle(TypeSize.body, .semibold)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.sm)
                Text("+\(outcome.totalXP) XP")
                    .font(Theme.Fonts.number(TypeSize.headline))
                    .foregroundStyle(Theme.Colors.success)
            }

            // "Labels are a last resort" (p48): the arithmetic is shown as a value that reads on
            // its own, not as "Base: 20  Streak: 1.45".
            if let award = outcome.awards.first, award.streakMultiplier > 1 {
                Text("\(award.baseXP) base, ×\(award.streakMultiplier, specifier: "%.2f") for the streak")
                    .textStyle(TypeSize.micro, .regular)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }

            facts

            if !outcome.levelUps.isEmpty || outcome.unlockedMilestoneTitle != nil || outcome.bossDefeated {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) { milestones }
            }

            if onUndo != nil || onDismiss != nil {
                HStack(spacing: Theme.Spacing.lg) {
                    if let onUndo { TertiaryButton(title: "Undo", action: onUndo) }
                    Spacer()
                    if let onDismiss { TertiaryButton(title: "Dismiss", action: onDismiss) }
                }
            }
        }
        .card(.medium, accent: Theme.Colors.success)
    }

    /// Each fact is an icon plus a number — never colour alone (p166).
    private var facts: some View {
        HStack(spacing: Theme.Spacing.base) {
            if outcome.streak > 1 {
                fact("flame.fill", "\(outcome.streak) days", Theme.Colors.gold)
            }
            if outcome.bossDamage > 0, let boss = outcome.bossName {
                fact("bolt.fill", "\(outcome.bossDamage) to \(boss)", Theme.Colors.hp)
            }
            if outcome.hpDelta > 0 {
                fact("heart.fill", "+\(outcome.hpDelta) HP", Theme.Colors.success)
            }
            Spacer(minLength: 0)
        }
    }

    private func fact(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(text).textStyle(TypeSize.micro, .semibold)
        }
        .foregroundStyle(tint)
    }

    @ViewBuilder
    private var milestones: some View {
        ForEach(Array(outcome.levelUps.enumerated()), id: \.offset) { _, event in
            fact("arrow.up.circle.fill", label(for: event), Theme.Colors.accent)
        }
        if let unlocked = outcome.unlockedMilestoneTitle {
            fact("lock.open.fill", "Unlocked \(unlocked)", Theme.Colors.gold)
        }
        if outcome.bossDefeated, let boss = outcome.bossName {
            fact("checkmark.seal.fill", "\(boss) defeated", Theme.Colors.gold)
        }
    }

    private func label(for event: LevelUpEvent) -> String {
        switch event.scope {
        case .character:          "Level \(event.newLevel)"
        case .skill(let domain):  "\(domain.title) level \(event.newLevel)"
        }
    }
}
