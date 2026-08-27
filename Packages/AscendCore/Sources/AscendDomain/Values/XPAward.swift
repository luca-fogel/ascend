import Foundation

/// One XP grant, with its arithmetic still visible.
///
/// The multipliers are carried rather than folded away so the UI can show *why* a task paid
/// 46 instead of 20 ("medium x1.6 streak x1.45") without recomputing anything or knowing the
/// formula. It also makes a failing test say which factor was wrong.
public struct XPAward: Sendable, Equatable, Hashable {
    public let domain: SkillDomain
    public let baseXP: Int
    public let streakMultiplier: Double
    public let cadenceWeight: Double
    public let total: Int

    public init(domain: SkillDomain, baseXP: Int, streakMultiplier: Double, cadenceWeight: Double, total: Int) {
        self.domain = domain
        self.baseXP = baseXP
        self.streakMultiplier = streakMultiplier
        self.cadenceWeight = cadenceWeight
        self.total = total
    }
}

/// Which pool levelled. Skill trees and the character level advance independently.
public enum LevelScope: Sendable, Equatable, Hashable {
    case character
    case skill(SkillDomain)
}

public struct LevelUpEvent: Sendable, Equatable, Hashable {
    public let scope: LevelScope
    public let newLevel: Int

    public init(scope: LevelScope, newLevel: Int) {
        self.scope = scope
        self.newLevel = newLevel
    }
}
