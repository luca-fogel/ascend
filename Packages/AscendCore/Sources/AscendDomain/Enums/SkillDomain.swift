import Foundation

/// The axis a completed task pushes on.
///
/// XP is deliberately *not* one universal pool: routing it per domain is what makes a
/// character read as a shape ("high Intellect, neglected Fitness") rather than a single
/// number, and it is what lets the roadmap generator tag each step it invents.
public enum SkillDomain: String, CaseIterable, Sendable, Codable, Hashable, Identifiable {
    case fitness
    case intellect
    case creativity
    case discipline
    case social
    case wealth

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fitness:    "Fitness"
        case .intellect:  "Intellect"
        case .creativity: "Creativity"
        case .discipline: "Discipline"
        case .social:     "Social"
        case .wealth:     "Wealth"
        }
    }

    /// An SF Symbol name. A plain `String` here, so naming an icon costs the core no
    /// SwiftUI import -- the view layer resolves it.
    public var symbolName: String {
        switch self {
        case .fitness:    "figure.run"
        case .intellect:  "brain.head.profile"
        case .creativity: "paintbrush.pointed.fill"
        case .discipline: "target"
        case .social:     "person.2.fill"
        case .wealth:     "chart.line.uptrend.xyaxis"
        }
    }
}
