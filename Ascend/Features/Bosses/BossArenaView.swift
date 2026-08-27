import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence

/// The bosses.
///
/// There is deliberately no attack button. Damage arrives as a side effect of completing real
/// work, because the whole conceit is that doing the task *is* the attack -- a button would
/// turn a framing device for a real failure mode into a tapping game.
struct BossArenaView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Boss.createdAt, order: .forward) private var bosses: [Boss]
    @State private var summoning = false
    @State private var error: AscendError?

    private var active: [Boss] { bosses.filter { !$0.isDefeated } }
    private var defeated: [Boss] { bosses.filter(\.isDefeated) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if let error { ErrorCard(error: error) }
                    if active.isEmpty && defeated.isEmpty {
                        NoBossesCard { summoning = true }
                    } else {
                        if !active.isEmpty {
                            sectionHeader("Facing")
                            ForEach(active) { BossCard(boss: $0) }
                        }
                        if !defeated.isEmpty {
                            sectionHeader("Defeated")
                            ForEach(defeated) { DefeatedBossRow(boss: $0) }
                        }
                        explainer
                    }
                }
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle("Bosses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { summoning = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Face a new boss")
                        .disabled(availableKinds.isEmpty)
                }
            }
            .sheet(isPresented: $summoning) {
                SummonSheet(kinds: availableKinds, onSummon: summon)
            }
        }
    }

    private var availableKinds: [BossKind] {
        guard let profile = try? DefaultSeed.profile(in: modelContext) else { return [] }
        return Roster.availableBossKinds(for: profile)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.micro)
            .foregroundStyle(Theme.Colors.tertiaryText)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var explainer: some View {
        Text("Bosses take damage when you finish real work \u{2014} about half the XP a step pays. There is nothing to tap here.")
            .font(Theme.Fonts.micro)
            .foregroundStyle(Theme.Colors.tertiaryText)
            .multilineTextAlignment(.center)
            .padding(.top, Theme.Spacing.sm)
    }

    private func summon(_ kind: BossKind, domain: SkillDomain?) {
        do {
            let profile = try DefaultSeed.profile(in: modelContext)
            try Roster.summonBoss(kind, domain: domain, for: profile, context: modelContext)
            summoning = false
        } catch let error as AscendError { self.error = error }
        catch { self.error = .invalidRoadmap(error.localizedDescription) }
    }
}

private struct BossCard: View {
    let boss: Boss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: boss.kind.symbolName)
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.Colors.hp)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.hp.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(boss.name)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.primaryText)
                    if let domain = boss.domain {
                        Label("Only \(domain.title) work hurts it", systemImage: domain.symbolName)
                            .font(Theme.Fonts.micro)
                            .foregroundStyle(domain.color)
                    } else {
                        Text("Any work hurts it")
                            .font(Theme.Fonts.micro)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
                Spacer()
                Text("\(Int(boss.hpFraction * 100))%")
                    .font(Theme.Fonts.number(16, .semibold))
                    .foregroundStyle(Theme.Colors.hp)
            }

            StatBar(fraction: boss.hpFraction, tint: Theme.Colors.hp, height: 10)

            HStack {
                Text("\(boss.currentHP) / \(boss.maxHP) HP")
                    .font(Theme.Fonts.number(12))
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
                if let deadline = boss.deadline {
                    Label(deadline.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "clock")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.gold)
                }
            }
        }
        .card()
    }
}

private struct DefeatedBossRow: View {
    let boss: Boss

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: boss.kind.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.success)
            Text(boss.name)
                .font(Theme.Fonts.bodyEmphasis)
                .foregroundStyle(Theme.Colors.secondaryText)
            Spacer()
            if let date = boss.defeatedAt {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.success)
        }
        .card(padding: Theme.Spacing.md)
    }
}

private struct SummonSheet: View {
    let kinds: [BossKind]
    let onSummon: @MainActor (BossKind, SkillDomain?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: BossKind?
    @State private var restrictDomain = false
    @State private var domain: SkillDomain = .discipline

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("A boss is a name for the thing that actually stops you. Pick the one that fits.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
        
                    ForEach(kinds, id: \.self) { kind in
                        Button { selected = kind } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: kind.symbolName)
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected == kind ? Theme.Colors.hp
                                                                      : Theme.Colors.secondaryText)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.displayName)
                                        .font(Theme.Fonts.bodyEmphasis)
                                        .foregroundStyle(Theme.Colors.primaryText)
                                    Text("\(kind.baseHP) HP")
                                        .font(Theme.Fonts.micro)
                                        .foregroundStyle(Theme.Colors.tertiaryText)
                                }
                                Spacer()
                                if selected == kind {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.Colors.hp)
                                }
                            }
                            .card(padding: Theme.Spacing.md)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Toggle("Only one kind of work hurts it", isOn: $restrictDomain)
                            .font(Theme.Fonts.bodyEmphasis)
                        if restrictDomain {
                            Picker("Domain", selection: $domain) {
                                ForEach(SkillDomain.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        Text("A restricted boss makes one neglected skill the only way forward.")
                            .font(Theme.Fonts.micro)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                    .card()

                    // "Face it" said nothing about what would happen; button text should state
                    // the action (p246). The boss name makes it unambiguous.
                    PrimaryButton(title: selected.map { "Start fighting \($0.displayName)" } ?? "Choose a boss",
                                  ramp: Palette.health,
                                  isEnabled: selected != nil) {
                        if let selected { onSummon(selected, restrictDomain ? domain : nil) }
                    }
                }
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(AscendBackground())
            .navigationTitle("New boss")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

private struct NoBossesCard: View {
    let onSummon: @MainActor () -> Void

    var body: some View {
        EmptyStateCard(
            symbolName: "shield.lefthalf.filled",
            title: "Nothing to fight",
            message: "Name the thing that actually stops you — procrastination, doubt, distraction — and your daily work starts wearing it down. There is nothing to tap.",
            actionTitle: "Choose a boss",
            onCreate: onSummon)
    }
}

#Preview {
    BossArenaView().appContainer(.preview())
}
