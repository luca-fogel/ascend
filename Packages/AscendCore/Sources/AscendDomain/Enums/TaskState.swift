import Foundation

public enum TaskState: String, CaseIterable, Sendable, Codable, Hashable {
    case pending
    case completed
    /// A daily step a rollover charged for. Distinct from `.skipped`, which the user chose.
    case missed
    case skipped
    /// Superseded by a recalibrated roadmap; kept rather than deleted so history survives.
    case rescheduled
}

public enum GoalStatus: String, CaseIterable, Sendable, Codable, Hashable {
    case draft
    case active
    case paused
    case completed
    case abandoned
}

public enum MilestoneStatus: String, CaseIterable, Sendable, Codable, Hashable {
    case locked
    case active
    case completed
}

/// Where a `CompletionLog` entry came from.
///
/// The log stores this plus a raw `sourceID` rather than a SwiftData relationship, so
/// deleting a goal cannot cascade away the ledger that proves what was awarded.
public enum CompletionSourceKind: String, CaseIterable, Sendable, Codable, Hashable {
    case task
    case habit
}
