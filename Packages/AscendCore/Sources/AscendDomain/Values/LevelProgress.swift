import Foundation

/// A level and how far into it you are. Everything a progress ring needs, already derived.
public struct LevelProgress: Sendable, Equatable, Hashable {
    public let level: Int
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int

    public init(level: Int, xpIntoLevel: Int, xpForNextLevel: Int) {
        self.level = level
        self.xpIntoLevel = xpIntoLevel
        self.xpForNextLevel = xpForNextLevel
    }

    /// 0...1, and never NaN -- the view layer feeds this straight into a ring.
    public var fraction: Double {
        guard xpForNextLevel > 0 else { return 1 }
        return min(1, max(0, Double(xpIntoLevel) / Double(xpForNextLevel)))
    }

    public var xpRemaining: Int { max(0, xpForNextLevel - xpIntoLevel) }
}
