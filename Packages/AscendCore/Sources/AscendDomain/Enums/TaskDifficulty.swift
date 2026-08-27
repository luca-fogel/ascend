import Foundation

/// How much a single step is worth -- and how much it stings to skip.
///
/// `baseXP` and `missDamage` are intentionally not proportional. Damage rises more slowly
/// than reward (an epic task pays 12x a trivial one but only hurts 10x) so that an
/// ambitious roadmap is never a worse bet than a timid one.
public enum TaskDifficulty: String, CaseIterable, Sendable, Codable, Hashable {
    case trivial
    case easy
    case medium
    case hard
    case epic

    public var baseXP: Int {
        switch self {
        case .trivial: 5
        case .easy:    10
        case .medium:  20
        case .hard:    35
        case .epic:    60
        }
    }

    public var missDamage: Int {
        switch self {
        case .trivial: 1
        case .easy:    2
        case .medium:  4
        case .hard:    7
        case .epic:    10
        }
    }

    public var title: String { rawValue.capitalized }
}
