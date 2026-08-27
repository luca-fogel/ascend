import Foundation

/// The named adversaries. A boss is a framing device for a real failure mode: you do not
/// fight a healthbar, you fight the thing that has been stopping you.
public enum BossKind: String, CaseIterable, Sendable, Codable, Hashable {
    case procrastination
    case doubt
    case distraction
    case inertia
    case burnout

    public var displayName: String {
        switch self {
        case .procrastination: "Procrastination"
        case .doubt:           "Self-Doubt"
        case .distraction:     "Distraction"
        case .inertia:         "Inertia"
        case .burnout:         "Burnout"
        }
    }

    public var symbolName: String {
        switch self {
        case .procrastination: "hourglass.bottomhalf.filled"
        case .doubt:           "questionmark.circle.fill"
        case .distraction:     "bell.badge.fill"
        case .inertia:         "mountain.2.fill"
        case .burnout:         "flame.fill"
        }
    }

    /// Starting HP, tuned so the first boss falls in roughly two focused weeks.
    public var baseHP: Int {
        switch self {
        case .procrastination: 400
        case .doubt:           550
        case .distraction:     500
        case .inertia:         700
        case .burnout:         900
        }
    }
}
