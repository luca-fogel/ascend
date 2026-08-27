import SwiftUI
import AscendDomain

/// The Apple Fitness-style progress ring, used for skill levels and the character bar.
struct RingGauge: View {
    let fraction: Double
    let tint: Color
    var lineWidth: CGFloat = 10
    var trackOpacity: Double = 0.16

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(trackOpacity), style: .init(lineWidth: lineWidth, lineCap: .round))
            // No arc at all when there is no progress. `max(0.001, ...)` used to force a
            // sliver, which a round line cap renders as a stray dot floating at 12 o'clock --
            // it reads as a bullet or a rendering artefact rather than as "nothing yet".
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.65), tint],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)),
                    style: .init(lineWidth: lineWidth, lineCap: .round)
                )
                // Start at 12 o'clock, the way every ring the user already knows does.
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 6)
                .opacity(fraction > 0 ? 1 : 0)
        }
        .animation(Theme.Motion.standard, value: fraction)
    }
}

/// A horizontal stat bar, for HP and boss health.
struct StatBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: height)
        .animation(Theme.Motion.standard, value: fraction)
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.xl) {
        HStack(spacing: Theme.Spacing.lg) {
            RingGauge(fraction: 0.72, tint: SkillDomain.fitness.color).frame(width: 76, height: 76)
            RingGauge(fraction: 0.34, tint: SkillDomain.intellect.color).frame(width: 76, height: 76)
            RingGauge(fraction: 0.95, tint: SkillDomain.creativity.color).frame(width: 76, height: 76)
        }
        StatBar(fraction: 0.42, tint: Theme.Colors.hp)
    }
    .padding(Theme.Spacing.xxl)
    .background(Theme.Colors.background)
}
