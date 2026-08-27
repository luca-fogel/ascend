import SwiftUI
import AscendDomain
import AscendPersistence

/// The character sheet.
///
/// It reads a `CharacterSnapshot` — an immutable value the engine derives — rather than touching
/// `UserProfile` or the progression curve.
///
/// **"Labels are a last resort" (p48)** is the rule that reshaped this screen. The vitals used to
/// be a `label: value` list — "Health" on the left, "42 / 50" on the right — which gives every
/// row identical emphasis and makes nothing scannable. Now the number leads and carries its own
/// unit, and the word "Health" is gone entirely: a red heart above a red bar does not need it.
struct CharacterView: View {
    @Environment(\.appContainer) private var container
    @State private var snapshot: CharacterSnapshot?
    @State private var loadError: AscendError?

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle("Character")
            .task { refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            VStack(spacing: Theme.Spacing.lg) {
                header(snapshot)
                vitals(snapshot)
                skills(snapshot)
            }
        } else if let loadError {
            ErrorCard(error: loadError)
        }
    }

    /// The one place in the app that earns display type.
    ///
    /// "Not all elements are equal" (p36): the character level is the headline fact of this
    /// screen, so everything else on it is deliberately quieter.
    private func header(_ snapshot: CharacterSnapshot) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                // A soft radial glow behind the ring. "Decorate your backgrounds" (p228) —
                // low contrast, so it lifts the panel without competing with the numeral.
                Circle()
                    .fill(RadialGradient(colors: [Theme.Colors.accent.opacity(0.16), .clear],
                                         center: .center, startRadius: 8, endRadius: 110))
                    .frame(width: 220, height: 220)
                RingGauge(fraction: snapshot.progress.fraction, tint: Theme.Colors.accent, lineWidth: 11)
                    .frame(width: 158, height: 158)
                VStack(spacing: -2) {
                    Text("\(snapshot.level)")
                        .font(Theme.Fonts.number(TypeSize.display))
                        .foregroundStyle(Theme.Colors.primaryText)
                    Text("level")
                        .textStyle(TypeSize.micro, .regular, allCaps: true)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
            .frame(height: 200)

            Text("\(snapshot.progress.xpRemaining) XP to level \(snapshot.level + 1)")
                .textStyle(TypeSize.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private func vitals(_ snapshot: CharacterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.base) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.hp.opacity(0.8))
                    // The value carries its own unit, so no label is needed.
                    Text("\(snapshot.currentHP)")
                        .font(Theme.Fonts.number(TypeSize.headline))
                        .foregroundStyle(Theme.Colors.primaryText)
                    Text("of \(snapshot.maxHP) HP")
                        .textStyle(TypeSize.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    Spacer()
                }
                StatBar(fraction: snapshot.hpFraction, tint: Theme.Colors.hp)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.gold.opacity(0.8))
                Text("\(snapshot.gold)")
                    .font(Theme.Fonts.number(TypeSize.headline))
                    .foregroundStyle(Theme.Colors.primaryText)
                Text("gold")
                    .textStyle(TypeSize.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                Spacer()
                if snapshot.defeatCount > 0 {
                    Text("\(snapshot.defeatCount) defeats")
                        .textStyle(TypeSize.micro, .regular)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }
        }
        .card()
    }

    private func skills(_ snapshot: CharacterSnapshot) -> some View {
        LabeledGroup("Skill trees") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3),
                      spacing: Theme.Spacing.lg) {
                ForEach(snapshot.skills) { skill in
                    SkillBadge(domain: skill.domain,
                               level: skill.level,
                               fraction: skill.progress.fraction)
                }
            }
            .card()
        }
    }

    private func refresh() {
        guard let container else { return }
        do { snapshot = try container.engine.snapshot() }
        catch let error as AscendError { loadError = error }
        catch { loadError = .noProfile }
    }
}

#Preview {
    CharacterView().appContainer(.preview())
}
