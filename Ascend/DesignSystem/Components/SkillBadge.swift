import SwiftUI
import AscendDomain

/// The one place a `SkillDomain` becomes a `Color`.
///
/// `AscendDomain` has no idea `Color` exists and the design system has no idea `SkillDomain`
/// does; this is the seam. It reads straight from `Palette`, so every domain colour in the app
/// is one the WCAG contrast sweep in `PaletteContrastTests` has already checked — there is no
/// second, untested list of hues.
extension SkillDomain {
    /// For text and icons on a dark surface. Not the base shade: at 60% lightness a saturated
    /// hue makes a fine button fill but thin text (Refactoring UI p164).
    var color: Color { Color(Palette.onSurface(self)) }
    var ramp: ColorRamp { Palette.ramp(for: self) }
}

struct SkillBadge: View {
    let domain: SkillDomain
    let level: Int
    let fraction: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RingGauge(fraction: fraction, tint: domain.color, lineWidth: 6)
                VStack(spacing: 1) {
                    // The icon is deliberately softer than the number beside it.
                    // "Balance weight and contrast" (p56): a solid glyph covers far more surface
                    // area than a numeral, so at equal colour it steals the emphasis. Lowering
                    // its contrast is the counterweight.
                    Image(systemName: domain.symbolName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(domain.color.opacity(0.75))
                    Text("\(level)")
                        .font(Theme.Fonts.number(15))
                        .foregroundStyle(Theme.Colors.primaryText)
                }
            }
            .frame(width: 66, height: 66)

            Text(domain.title)
                .textStyle(TypeSize.micro, .regular)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
    }
}
