import SwiftUI

struct RootView: View {
    /// Which tab to open on.
    ///
    /// Settable from the command line so that every screen can be screenshotted without driving
    /// the UI: `xcrun simctl launch <device> com.foggylulu.Ascend -tab character`. Synthetic taps
    /// do not reach the simulator reliably, and a design system whose screens cannot be looked at
    /// is a design system that drifts. Mirrors the approach in solvr-ai's tools/screenshots.sh.
    ///
    /// The enum is `RootTab`, not `Tab`: `SwiftUI.Tab` is the view builder used three lines
    /// below, and shadowing it produces "requires that Tab conform to TabContent", which reads
    /// like a protocol problem rather than a name collision. Same trap as `Task` and `Section`
    /// elsewhere in this project.
    @State private var selection: RootTab = RootTab(launchArgument: ProcessInfo.processInfo.arguments)

    enum RootTab: Hashable {
        case today, goals, bosses, character, settings

        init(launchArgument arguments: [String]) {
            guard let index = arguments.firstIndex(of: "-tab"), index + 1 < arguments.count else {
                self = .today
                return
            }
            switch arguments[index + 1].lowercased() {
            case "goals":     self = .goals
            case "bosses":    self = .bosses
            case "character": self = .character
            case "settings":  self = .settings
            default:          self = .today
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "checklist", value: RootTab.today) { TodayView() }
            Tab("Goals", systemImage: "map", value: RootTab.goals) { GoalListView() }
            Tab("Bosses", systemImage: "shield.lefthalf.filled", value: RootTab.bosses) { BossArenaView() }
            Tab("Character", systemImage: "person.crop.circle", value: RootTab.character) { CharacterView() }
            Tab("Settings", systemImage: "gearshape", value: RootTab.settings) { SettingsView() }
        }
        .tint(Theme.Colors.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView().appContainer(.preview())
}
