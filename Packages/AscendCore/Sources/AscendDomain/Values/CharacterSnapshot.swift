import Foundation

public struct SkillSnapshot: Sendable, Equatable, Hashable, Identifiable {
    public let domain: SkillDomain
    public let totalXP: Int
    public let progress: LevelProgress

    public var id: SkillDomain { domain }
    public var level: Int { progress.level }

    public init(domain: SkillDomain, totalXP: Int, progress: LevelProgress) {
        self.domain = domain
        self.totalXP = totalXP
        self.progress = progress
    }
}

/// Everything the character header renders, computed once.
///
/// A snapshot rather than a live model reference: views bind to an immutable value, so a
/// mid-animation store mutation cannot tear the numbers being drawn.
public struct CharacterSnapshot: Sendable, Equatable, Hashable {
    public let displayName: String
    public let progress: LevelProgress
    public let currentHP: Int
    public let maxHP: Int
    public let gold: Int
    public let skills: [SkillSnapshot]
    public let defeatCount: Int

    public init(displayName: String,
                progress: LevelProgress,
                currentHP: Int,
                maxHP: Int,
                gold: Int,
                skills: [SkillSnapshot],
                defeatCount: Int) {
        self.displayName = displayName
        self.progress = progress
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.gold = gold
        self.skills = skills
        self.defeatCount = defeatCount
    }

    public var level: Int { progress.level }

    public var hpFraction: Double {
        guard maxHP > 0 else { return 0 }
        return min(1, max(0, Double(currentHP) / Double(maxHP)))
    }

    public var strongestSkill: SkillSnapshot? { skills.max { $0.totalXP < $1.totalXP } }
    public var weakestSkill: SkillSnapshot? { skills.min { $0.totalXP < $1.totalXP } }
}
