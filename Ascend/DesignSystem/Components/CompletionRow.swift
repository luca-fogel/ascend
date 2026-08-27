import SwiftUI
import AscendDomain

/// A tappable piece of work.
///
/// Two rules shape this row:
///
/// **"Labels are a last resort" (p48).** The metadata line used to read as two labelled
/// fragments; it now reads as values that carry their own meaning — "Medium · daily" and a
/// streak as a flame with a number. Nothing says "Difficulty:".
///
/// **"Balance weight and contrast" (p56).** The trailing domain glyph is softened, because a
/// solid icon covers far more surface area than the text beside it and at equal contrast it
/// pulls the eye away from the thing that matters, which is the title.
struct CompletionRow: View {
    let title: String
    let detail: String
    let domain: SkillDomain
    let difficulty: TaskDifficulty
    let streak: Int?
    let onComplete: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Button(action: onComplete) {
                // The glyph stays 24pt; the hit area is 44pt. Filipiuk p128: the tappable region
                // of a small interactive element has to be finger-sized even when the mark is
                // not, or people with larger fingers miss it.
                Image(systemName: "circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(domain.color)
                    .tapTarget()
            }
            .buttonStyle(PressableButtonStyle(scale: 0.88))
            .accessibilityLabel("Complete \(title)")

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .textStyle(TypeSize.body, .semibold)
                    .foregroundStyle(Theme.Colors.primaryText)
                if !detail.isEmpty {
                    Text(detail)
                        .textStyle(TypeSize.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(2)
                }
                metadata
            }

            Spacer(minLength: 0)

            Image(systemName: domain.symbolName)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(domain.color.opacity(0.55))
        }
        .card(.low, padding: Theme.Spacing.base)
    }

    private var metadata: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(difficulty.title) · \(cadenceWord)")
                .textStyle(TypeSize.micro, .regular)
                .foregroundStyle(Theme.Colors.tertiaryText)
            if let streak, streak > 0 {
                // Icon plus number, never colour alone (p166): a flame reads as a streak to
                // someone who cannot distinguish the gold from the grey beside it.
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 9))
                    Text("\(streak)").font(Theme.Fonts.number(TypeSize.micro))
                }
                .foregroundStyle(Theme.Colors.gold)
            }
        }
    }

    private var cadenceWord: String {
        streak == nil ? "step" : "daily"
    }
}
