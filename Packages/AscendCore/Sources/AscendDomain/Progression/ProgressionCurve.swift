import Foundation

/// How much XP a level costs.
///
/// `xpForNextLevel(after: L) = round(base * L^exponent + linear * L)`
///
/// Two things about this type are deliberate:
///
/// 1. **Thresholds are precomputed in `init`, not cached lazily.** A value type cannot
///    memoise on demand without a lock, and `level(forTotalXP:)` is called for every row
///    on screen. Paying ~`maxLevel` `pow` calls once at construction (the presets are
///    `static let`, so effectively once per process) buys a binary-search lookup that is
///    thread-safe by construction.
/// 2. **Level is always derived from total XP, never stored.** Storing both invites the
///    two to drift, and it turns retuning the curve into a data migration instead of a
///    recompile. `totalXP` is monotonic, so ordering by XP is ordering by level.
public struct ProgressionCurve: Sendable, Equatable, Hashable {

    /// Levels beyond this are not representable. Bounds the threshold table so absurd XP
    /// (a corrupt store, a test with `Int.max`) cannot spin a loop.
    public static let maxLevel = 500

    public let base: Double
    public let exponent: Double
    public let linear: Double

    /// `thresholds[i]` is the total XP required to *reach* level `i + 1`.
    /// So `thresholds[0] == 0`: level 1 is free.
    private let thresholds: [Int]

    public init(base: Double, exponent: Double, linear: Double) {
        self.base = base
        self.exponent = exponent
        self.linear = linear

        var table = [Int](repeating: 0, count: Self.maxLevel)
        var running = 0
        for level in 1..<Self.maxLevel {
            running += Self.cost(base: base, exponent: exponent, linear: linear, level: level)
            table[level] = running
        }
        self.thresholds = table
    }

    /// A skill tree only ever receives XP from its own domain.
    public static let skill = ProgressionCurve(base: 60, exponent: 1.30, linear: 40)

    /// The character pool receives XP from every domain at once, so it must climb steeper
    /// or the headline level outruns every skill behind it.
    public static let character = ProgressionCurve(base: 220, exponent: 1.35, linear: 120)

    /// Computed in `Double` and rounded exactly once -- rounding the terms separately
    /// drifts the table by a point or two per level, which compounds over 500 levels.
    ///
    /// Clamped to at least 1: a zero or negative cost would make the level-up loop in
    /// `GameManager` non-terminating, so the invariant is enforced here at the source
    /// rather than defended at every call site.
    private static func cost(base: Double, exponent: Double, linear: Double, level: Int) -> Int {
        let raw = base * pow(Double(level), exponent) + linear * Double(level)
        return max(1, Int(raw.rounded()))
    }

    /// XP needed to go from `level` to `level + 1`. Always >= 1.
    public func xpForNextLevel(after level: Int) -> Int {
        guard level >= 1 else { return Self.cost(base: base, exponent: exponent, linear: linear, level: 1) }
        guard level < Self.maxLevel else { return Int.max }
        return Self.cost(base: base, exponent: exponent, linear: linear, level: level)
    }

    /// Total XP required to reach `level` from scratch. `totalXP(toReach: 1) == 0`.
    public func totalXP(toReach level: Int) -> Int {
        let clamped = min(max(level, 1), Self.maxLevel)
        return thresholds[clamped - 1]
    }

    /// Binary search rather than a walk from level 1 -- this runs per row, per frame.
    public func level(forTotalXP totalXP: Int) -> Int {
        guard totalXP > 0 else { return 1 }
        var low = 0
        var high = thresholds.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if thresholds[mid] <= totalXP { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }

    public func progress(forTotalXP totalXP: Int) -> LevelProgress {
        let xp = max(0, totalXP)
        let level = level(forTotalXP: xp)
        let floorXP = self.totalXP(toReach: level)
        let needed = xpForNextLevel(after: level)
        let into = xp - floorXP
        return LevelProgress(level: level, xpIntoLevel: into, xpForNextLevel: needed)
    }
}
