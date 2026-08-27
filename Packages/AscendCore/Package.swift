// swift-tools-version: 6.3
import PackageDescription

// Three targets, because three different things are true about them.
//
//   AscendDomain        Foundation only. Pure value types and the progression arithmetic.
//                       Runs anywhere, needs no simulator and no Apple Intelligence.
//   AscendPersistence   + SwiftData. The @Model classes and the game engine.
//   AscendIntelligence  + FoundationModels. On-device roadmap generation.
//
// The dependency arrows are the point. AscendIntelligence depends on Domain and *not* on
// Persistence: the AI layer emits plain DTOs and a RoadmapImporter over in Persistence turns
// them into stored models. So the generator can never reach into the store, and none of its
// tests need a ModelContainer.
//
// Splitting also keeps the fast tests fast: editing a @Guide string in the AI layer does not
// re-expand every @Model macro, and `swift test` on the arithmetic stays honest about having
// no framework dependencies at all.
//
// Nothing here may import SwiftUI or UIKit. tools/check.sh fails the build if that changes.
let package = Package(
    name: "AscendCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "AscendDomain", targets: ["AscendDomain"]),
        .library(name: "AscendPersistence", targets: ["AscendPersistence"]),
        .library(name: "AscendIntelligence", targets: ["AscendIntelligence"]),
        .executable(name: "ascend-eval", targets: ["ascend-eval"]),
        .executable(name: "ascend-icon", targets: ["ascend-icon"]),
    ],
    targets: [
        .target(name: "AscendDomain"),

        // MainActor-by-default: every @Model and GameManager itself is main-actor-only
        // (ModelContainer.mainContext is @MainActor and ModelContext's Sendable conformance
        // is explicitly unavailable). Declaring it here puts the isolation boundary where the
        // real constraint is, instead of leaving Domain's pure value types pinned to the main
        // actor for no reason.
        .target(
            name: "AscendPersistence",
            dependencies: ["AscendDomain"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        .target(name: "AscendIntelligence", dependencies: ["AscendDomain"]),

        // Runs the real on-device prompts and scores their output.
        //
        // Apple Intelligence cannot run under `swift test`, so prompt quality would otherwise
        // be unmeasurable -- the only feedback would be someone saying the roadmaps feel
        // generic, with no way to tell whether a prompt edit helped. This harness closes that
        // loop on any Mac with Apple Intelligence enabled.
        .executableTarget(name: "ascend-eval", dependencies: ["AscendDomain", "AscendIntelligence"]),

        // Renders the app icon from the same Palette the app draws itself with.
        //
        // An icon committed as a bare PNG is a design decision nobody can review or re-derive.
        // This way the colours are provably the app's own -- if the accent hue changes, the icon
        // changes with it -- and the geometry is readable as code.
        .executableTarget(name: "ascend-icon", dependencies: ["AscendDomain"]),

        .testTarget(name: "AscendDomainTests", dependencies: ["AscendDomain"]),
        .testTarget(
            name: "AscendPersistenceTests",
            dependencies: ["AscendPersistence"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "AscendIntelligenceTests", dependencies: ["AscendIntelligence"]),
    ]
)
