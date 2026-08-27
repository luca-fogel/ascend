import Foundation
import AscendDomain
import AscendIntelligence

// Runs the real on-device planner against a fixed set of goals and scores the output, so
// "the roadmaps feel generic" becomes a number that a prompt edit either moves or doesn't.
//
//   swift run ascend-eval            # all goals, summary + full roadmaps
//   swift run ascend-eval --quiet    # scores only
//
// Requires a Mac with Apple Intelligence enabled. This is the only place prompt quality can be
// measured at all: Apple Intelligence cannot run under `swift test`.

let goals: [RoadmapRequest] = [
    RoadmapRequest(goalText: "Get into Equinox shape",
                   horizonWeeks: 8, minutesPerDay: 45, preferredDomains: [.fitness]),
    RoadmapRequest(goalText: "Learn SwiftUI well enough to ship an app to the App Store",
                   horizonWeeks: 10, minutesPerDay: 60, preferredDomains: [.intellect]),
    RoadmapRequest(goalText: "Write and record five original songs",
                   horizonWeeks: 12, minutesPerDay: 40, preferredDomains: [.creativity]),
    RoadmapRequest(goalText: "Read 12 books this year and remember what is in them",
                   horizonWeeks: 16, minutesPerDay: 30, preferredDomains: [.intellect]),
]

let quiet = CommandLine.arguments.contains("--quiet")
let onlyFirst = CommandLine.arguments.contains("--first")
// Select a single goal by index, for chasing one goal's failures.
let goalIndex: Int? = {
    guard let i = CommandLine.arguments.firstIndex(of: "--goal"),
          i + 1 < CommandLine.arguments.count,
          let n = Int(CommandLine.arguments[i + 1]) else { return nil }
    return n
}()
// Repeats matter: on-device sampling makes a single run a poor estimate, and a prompt change
// smaller than the run-to-run spread cannot be judged from one sample.
let runs: Int = {
    guard let i = CommandLine.arguments.firstIndex(of: "--runs"),
          i + 1 < CommandLine.arguments.count,
          let n = Int(CommandLine.arguments[i + 1]) else { return 1 }
    return max(1, n)
}()

guard #available(macOS 26.0, *) else {
    print("needs macOS 26"); exit(1)
}

let service = OnDeviceRoadmapService()
if let reason = service.unavailableReason {
    print("Apple Intelligence unavailable: \(reason.title) -- \(reason.errorDescription ?? "")")
    exit(1)
}

func render(_ draft: RoadmapDraft, _ score: GenericnessScore, _ request: RoadmapRequest, seconds: Double) {
    print("\n" + String(repeating: "=", count: 76))
    print("GOAL: \(request.goalText)")
    print("SCORE \(score.score)/100   concreteness \(Int(score.concreteness * 100))%   "
          + "difficulties \(score.distinctDifficulties)   cadences \(score.distinctCadences)   "
          + "avg title \(String(format: "%.1f", score.averageTitleWords))w   \(String(format: "%.1f", seconds))s")
    if !score.fillerHits.isEmpty {
        print("FILLER: \(score.fillerHits.joined(separator: ", "))")
    }
    if !score.goalEchoes.isEmpty {
        print("ECHOES THE GOAL: \(score.goalEchoes.joined(separator: " | "))")
    }
    guard !quiet else { return }
    print(String(repeating: "-", count: 76))
    print("TITLE:   \(draft.title)")
    print("SUMMARY: \(draft.summary)")
    print("DOMAIN:  \(draft.primaryDomain.rawValue)")
    for milestone in draft.milestones {
        print("\n  \(milestone.orderIndex + 1). \(milestone.title)")
        if !milestone.detail.isEmpty { print("     \(milestone.detail)") }
        for task in milestone.tasks {
            let flag = GenericnessScore.isConcrete(task.title) ? " " : "~"
            print("     \(flag) [\(task.difficulty.rawValue)/\(task.cadence.rawValue)/\(task.domain.rawValue)] \(task.title)")
            if !task.detail.isEmpty { print("         \(task.detail)") }
        }
    }
}

var scores: [Int] = []
var perGoal: [String: [Int]] = [:]
let selected: [RoadmapRequest] = {
    if let goalIndex, goals.indices.contains(goalIndex) { return [goals[goalIndex]] }
    return onlyFirst ? Array(goals.prefix(1)) : goals
}()
for request in selected {
  for _ in 0..<runs {
    let start = Date()
    do {
        var draft = try await service.milestonePlan(for: request)
        // Stage two for every tier, so the harness sees what the user eventually sees rather
        // than only the first tier the app generates eagerly.
        for index in draft.milestones.indices {
            let context = PlanContext.forMilestone(at: index, in: draft)
            draft.milestones[index].tasks = try await service.tasks(for: draft.milestones[index],
                                                                    in: request,
                                                                    context: context)
        }
        let elapsed = Date().timeIntervalSince(start)
        let score = GenericnessScore.evaluate(draft, goalText: request.goalText)
        scores.append(score.score)
        perGoal[request.goalText, default: []].append(score.score)
        render(draft, score, request, seconds: elapsed)
    } catch {
        print("\nGOAL: \(request.goalText)\n  FAILED: \(error)")
        scores.append(0)
        perGoal[request.goalText, default: []].append(0)
    }
  }
}

print("\n" + String(repeating: "=", count: 76))
let mean = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
for (goal, values) in perGoal.sorted(by: { $0.key < $1.key }) {
    let m = values.reduce(0, +) / values.count
    let spread = (values.max() ?? 0) - (values.min() ?? 0)
    print("  \(m)/100  spread \(spread)  \(values.map(String.init).joined(separator: ",")) \(goal.prefix(46))")
}
print("MEAN SCORE: \(mean)/100 over \(scores.count) runs (\(runs) per goal)")
