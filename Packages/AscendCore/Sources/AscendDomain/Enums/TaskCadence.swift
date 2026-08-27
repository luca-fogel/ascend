import Foundation

/// How often a step recurs.
///
/// Only `.daily` participates in streaks and in miss damage at rollover: a weekly or
/// one-shot step cannot be "missed today", and punishing it as though it could is the
/// fastest way to make a tracker feel unfair.
public enum TaskCadence: String, CaseIterable, Sendable, Codable, Hashable {
    case daily
    case weekly
    case oneShot

    /// Weekly and one-shot steps pay a premium because they arrive less often.
    public var xpWeight: Double {
        switch self {
        case .daily:   1.0
        case .weekly:  1.6
        case .oneShot: 1.3
        }
    }

    /// Whether a rollover may charge HP for not having done this today.
    public var accruesMissDamage: Bool { self == .daily }

    /// Whether consecutive completions build a streak multiplier.
    public var buildsStreak: Bool { self == .daily }
}
