import Foundation
import AscendDomain

/// What the presentation layer is allowed to ask of the game.
///
/// Views and view models depend on this, never on `GameManager` directly, so a preview or a
/// test can stand in a fake without a `ModelContext`.
@MainActor
public protocol GameEngine {
    func complete(_ task: QuestTask) throws -> CompletionOutcome
    func uncomplete(_ task: QuestTask) throws
    func complete(_ habit: Habit) throws -> CompletionOutcome
    func processDayRolloverIfNeeded() throws -> [RolloverReport]
    func snapshot() throws -> CharacterSnapshot
    func streak(forHabit habit: Habit) throws -> Int
}
