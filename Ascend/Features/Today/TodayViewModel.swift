import Foundation
import SwiftData
import AscendDomain
import AscendPersistence
import AscendIntelligence

/// Today's actions: completing, undoing, and noticing when a goal has drifted.
@Observable
final class TodayViewModel {

    private(set) var lastOutcome: CompletionOutcome?
    /// The completion `lastOutcome` came from, so Undo knows what to reverse.
    private(set) var lastCompletedTask: QuestTask?
    private(set) var lastCompletedHabit: Habit?
    private(set) var error: AscendError?

    // MARK: Recalibration
    private(set) var driftingGoal: Goal?
    private(set) var driftingDays: Int = 0
    private(set) var patch: RoadmapPatch?
    private(set) var isRecalibrating = false
    private(set) var recalibrationAccepted: String?

    func clearError() { error = nil }

    // MARK: - Completing

    @MainActor
    func complete(_ task: QuestTask, using engine: any GameEngine) {
        do {
            lastOutcome = try engine.complete(task)
            lastCompletedTask = task
            lastCompletedHabit = nil
            error = nil
        } catch let error as AscendError { self.error = error }
        catch { self.error = .generationFailed(error.localizedDescription) }
    }

    @MainActor
    func complete(_ habit: Habit, using engine: any GameEngine) {
        do {
            lastOutcome = try engine.complete(habit)
            lastCompletedHabit = habit
            lastCompletedTask = nil
            error = nil
        } catch let error as AscendError { self.error = error }
        catch { self.error = .generationFailed(error.localizedDescription) }
    }

    var canUndo: Bool { lastCompletedTask != nil && lastOutcome != nil }

    /// Undoes the last completion.
    ///
    /// Only quest tasks are undoable. A habit has no "uncompleted" state to return to -- the
    /// engine's reversal is written against a task's `.pending`, and inventing an equivalent
    /// for habits would mean guessing at streak state a rollover may already have consumed.
    /// The button simply does not appear for habits, which is better than offering one that
    /// fails.
    @MainActor
    func undoLast(using engine: any GameEngine) {
        guard let task = lastCompletedTask else { return }
        do {
            try engine.uncomplete(task)
            lastOutcome = nil
            lastCompletedTask = nil
            error = nil
        } catch let error as AscendError { self.error = error }
        catch { self.error = .generationFailed(error.localizedDescription) }
    }

    func dismissOutcome() {
        lastOutcome = nil
        lastCompletedTask = nil
        lastCompletedHabit = nil
    }

    // MARK: - Drift detection

    @MainActor
    func checkForDrift(profile: UserProfile, context: ModelContext, now: Date, calendar: Calendar) {
        let streaks = StreakCalculator(calendar: calendar, dayStartHour: profile.dayStartHour)
        guard let found = try? RecalibrationAdvisor.goalNeedingRecalibration(
            profile: profile, context: context, streaks: streaks, now: now) else {
            driftingGoal = nil
            driftingDays = 0
            return
        }
        driftingGoal = found.goal
        driftingDays = found.missedDays
    }

    @MainActor
    func requestWayBack(using service: any AIRoadmapService) async {
        guard let goal = driftingGoal, !isRecalibrating else { return }
        isRecalibrating = true
        error = nil
        defer { isRecalibrating = false }
        do {
            patch = try await service.recalibrate(
                RecalibrationAdvisor.request(for: goal, missedDays: driftingDays))
        } catch let error as AscendError { self.error = error }
        catch { self.error = .generationFailed(error.localizedDescription) }
    }

    @MainActor
    func acceptWayBack(context: ModelContext) {
        guard let goal = driftingGoal, let patch else { return }
        do {
            let milestone = try RoadmapImporter.importPatch(patch, into: goal, context: context)
            recalibrationAccepted = milestone?.title
            self.patch = nil
            driftingGoal = nil
            driftingDays = 0
        } catch let error as AscendError { self.error = error }
        catch { self.error = .invalidRoadmap(error.localizedDescription) }
    }

    func declineWayBack() {
        patch = nil
        // The goal stays flagged, so the offer returns tomorrow rather than being suppressed
        // forever by one dismissal.
    }
}
