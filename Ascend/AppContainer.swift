import Foundation
import SwiftUI
import SwiftData
import AscendDomain
import AscendPersistence
import AscendIntelligence

/// The composition root: the one place that knows which concrete services exist.
///
/// Views and view models receive this and see only protocol types, so a preview can inject
/// `TemplateRoadmapService` and a test can inject a fake without either of them being able to
/// reach a real model or a real store. This is deliberately an object handed down the tree
/// rather than a static factory: solvr-ai resolves its provider through a static
/// `ProviderFactory.current()` switch, and its own notes record the consequence -- "no DI
/// container to hang a second provider off".
///
/// `@Observable` rather than `ObservableObject`, matching the rest of this codebase.
@Observable
final class AppContainer {

    let modelContainer: ModelContainer
    let engine: any GameEngine
    /// The roadmap generator actually in use. `identifier` records which one produced any
    /// given goal, so a strange plan can be traced back to its author.
    let roadmapService: any AIRoadmapService
    /// Always present, whatever the primary provider is. This is what the "Use a template"
    /// button on an error runs, so an ineligible device or a refused phrasing still ends with a
    /// usable roadmap instead of a dead end.
    let templateService: any AIRoadmapService = TemplateRoadmapService()
    /// Non-nil when Apple Intelligence is unavailable, already phrased for display.
    private(set) var aiUnavailableReason: AscendError?

    init(modelContainer: ModelContainer,
         engine: any GameEngine,
         roadmapService: any AIRoadmapService) {
        self.modelContainer = modelContainer
        self.engine = engine
        self.roadmapService = roadmapService
    }

    /// Builds the production graph.
    ///
    /// The provider choice is made once at launch from real availability, not from an OS
    /// version check: on iOS 26 Apple Intelligence can still be absent because the hardware is
    /// ineligible, it is switched off, or the model is mid-download. In every one of those
    /// cases the app stays fully usable and roadmaps come from the template planner.
    @MainActor
    static func live() -> AppContainer {
        let modelContainer: ModelContainer
        do {
            modelContainer = try AscendStore.container()
        } catch {
            // A store that cannot open is unrecoverable and shipping a silent in-memory
            // fallback would lose the user's history without telling them.
            fatalError("Ascend could not open its data store: \(error)")
        }

        let engine = GameManager(container: modelContainer)
        let onDevice = OnDeviceRoadmapService()
        let container = AppContainer(
            modelContainer: modelContainer,
            engine: engine,
            roadmapService: onDevice.isConfigured ? onDevice : TemplateRoadmapService()
        )
        container.aiUnavailableReason = onDevice.unavailableReason
        if onDevice.isConfigured {
            // Loading the model on first use would put a multi-second stall in front of the
            // user's first roadmap. Warming it at launch moves that cost somewhere invisible.
            onDevice.prewarm()
        }
        return container
    }

    /// For previews and UI work: deterministic, no store on disk, no model download.
    @MainActor
    static func preview() -> AppContainer {
        let modelContainer = try! AscendStore.inMemoryContainer()
        let context = modelContainer.mainContext
        _ = try? DefaultSeed.profile(in: context)
        return AppContainer(modelContainer: modelContainer,
                            engine: GameManager(context: context),
                            roadmapService: TemplateRoadmapService())
    }
}
