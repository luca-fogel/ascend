import SwiftUI

private struct AppContainerKey: EnvironmentKey {
    /// No default. A missing container is a wiring bug that should surface immediately in
    /// development, not resolve to a silent stub that makes the app look like it works.
    static var defaultValue: AppContainer? { nil }
}

extension EnvironmentValues {
    var appContainer: AppContainer? {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}

extension View {
    func appContainer(_ container: AppContainer) -> some View {
        environment(\.appContainer, container)
            .modelContainer(container.modelContainer)
    }
}
