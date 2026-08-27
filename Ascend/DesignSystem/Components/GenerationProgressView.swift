import SwiftUI

/// The wait, made legible.
///
/// It names the actual stage rather than showing an indeterminate spinner, because on-device
/// generation takes several seconds per call and a spinner with no explanation is
/// indistinguishable from a hang. The two stages are also genuinely different work, and saying
/// so makes the second one feel like progress instead of a stall.
struct GenerationProgressView: View {
    let stage: GoalCreationViewModel.Stage
    let goalText: String

    @State private var pulse = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.accent.opacity(0.15), lineWidth: 2)
                    .scaleEffect(pulse ? 1.25 : 0.9)
                    .opacity(pulse ? 0 : 1)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .frame(width: 96, height: 96)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text(stage.label)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
                        .contentTransition(.opacity)
                Text(goalText)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                        .lineLimit(2)
            }

            stageIndicator
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
        .card(padding: Theme.Spacing.xl)
    }

    private var stageIndicator: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? Theme.Colors.accent : Theme.Colors.hairline)
                    .frame(width: index == currentIndex ? 26 : 16, height: 4)
            }
        }
        .animation(Theme.Motion.standard, value: currentIndex)
    }

    private var currentIndex: Int {
        switch stage {
        case .milestones: 0
        case .steps:      1
        }
    }
}
