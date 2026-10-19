import SwiftUI
import SwiftData
import AscendPersistence

@main
struct AscendApp: App {
    @State private var container = AppContainer.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .appContainer(container)
                .task { seedAndRoll() }
                .onChange(of: scenePhase) { _, phase in
                    // Returning to the app is when a day may have ended. `processDayRollover-
                    // IfNeeded` is idempotent and guarded, which is exactly why it is safe to
                    // call from a lifecycle event that fires more than once.
                    if phase == .active { seedAndRoll() }
                }
        }
    }

    private func seedAndRoll() {
        let context = container.modelContainer.mainContext
        do {
            _ = try DefaultSeed.profile(in: context)
            _ = try container.engine.processDayRolloverIfNeeded()
        } catch {
            // Surfaced in Settings rather than as an alert on launch: a rollover failure is
            // not something the user can act on mid-tap.
            container.recordStartupError(error)
        }
    }
}
