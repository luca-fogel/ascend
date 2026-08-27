import SwiftUI
import AscendDomain

/// The app background.
///
/// "Decorate your backgrounds" (p228): a flat fill everywhere reads plain no matter how good the
/// hierarchy above it is. This is a very slight vertical gradient between two hues about 14
/// degrees apart — the book's guidance is to stay under 30 — plus one soft off-screen glow.
///
/// Contrast is kept deliberately low. Every panel and every piece of text still sits on a colour
/// the WCAG sweep measured, because the gradient never gets light enough to matter: both ends are
/// darker than `Palette.surface`.
struct AscendBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(HSL(228, 0.26, 0.055)), Color(HSL(214, 0.22, 0.032))],
                startPoint: .top,
                endPoint: .bottom
            )
            // Anchored off the top-left corner so it reads as ambient light rather than as a
            // shape someone placed.
            RadialGradient(colors: [Theme.Colors.accent.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.1, y: -0.05),
                           startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}
