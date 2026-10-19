import SwiftUI
import AscendDomain
import AscendPersistence

/// Where the on-device AI reports for duty.
///
/// This screen is the only honest way to verify the Apple Intelligence path: it cannot be
/// exercised on the simulator or under `swift test`, so what ships is a surface that states
/// the real `SystemLanguageModel.availability` reason on a real device rather than a claim
/// that it was tested.
struct SettingsView: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        NavigationStack {
            List {
                Section("On-device intelligence") {
                    LabeledContent("Planner", value: container?.roadmapService.identifier ?? "-")
                    if let reason = container?.aiUnavailableReason {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Label(reason.title, systemImage: reason.symbolName)
                                .font(Theme.Fonts.bodyEmphasis)
                            if let message = reason.errorDescription {
                                Text(message)
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                        }
                    } else {
                        Label("Apple Intelligence is ready", systemImage: "checkmark.seal.fill")
                            .font(Theme.Fonts.bodyEmphasis)
                            .foregroundStyle(Theme.Colors.success)
                    }
                }

                if let startupError = container?.lastStartupError {
                    Section("Startup") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Label("Day rollover did not finish", systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.Fonts.bodyEmphasis)
                                .foregroundStyle(Theme.Colors.hp)
                            Text(startupError)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Button("Dismiss") {
                                container?.clearStartupError()
                            }
                            .font(Theme.Fonts.caption)
                        }
                    }
                }

                Section {
                    Label("Nothing leaves this device", systemImage: "lock.shield")
                        .font(Theme.Fonts.bodyEmphasis)
                } footer: {
                    Text("Ascend plans roadmaps entirely on your iPhone. There is no account, no server and no API key -- a build-time check fails if any networking code is ever added.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AscendBackground())
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView().appContainer(.preview())
}
