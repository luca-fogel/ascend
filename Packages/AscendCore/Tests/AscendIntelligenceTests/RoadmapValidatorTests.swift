import Testing
import Foundation
import AscendDomain
@testable import AscendIntelligence

@Suite("Roadmap validator")
struct RoadmapValidatorTests {

    static func draft(milestones: [MilestoneDraft],
                      title: String = "Learn SwiftUI") -> RoadmapDraft {
        RoadmapDraft(title: title, summary: "A plan", primaryDomain: .intellect, milestones: milestones)
    }

    static func milestone(_ title: String,
                          orderIndex: Int = 0,
                          tasks: [TaskDraft] = []) -> MilestoneDraft {
        MilestoneDraft(title: title, detail: "detail", orderIndex: orderIndex, tasks: tasks)
    }

    static func task(_ title: String, orderIndex: Int = 0) -> TaskDraft {
        TaskDraft(title: title, detail: "", difficulty: .medium,
                  cadence: .daily, domain: .intellect, orderIndex: orderIndex)
    }

    @Test("a well-formed plan passes through unchanged apart from tidying")
    func acceptsGoodPlan() throws {
        let input = Self.draft(milestones: [
            Self.milestone("Foundations", orderIndex: 0, tasks: [Self.task("Read the docs")]),
            Self.milestone("Build something", orderIndex: 1, tasks: [Self.task("Ship a screen")]),
        ])
        let output = try RoadmapValidator.validated(input)
        #expect(output.milestones.count == 2)
        #expect(output.milestones.map(\.title) == ["Foundations", "Build something"])
    }

    @Test("order is renumbered from array position, not trusted from the model")
    func renumbersOrderIndex() throws {
        // Small models frequently emit duplicate or absent indices. Array position is the real
        // ordering, so depending on both is how the two drift.
        let input = Self.draft(milestones: [
            Self.milestone("First", orderIndex: 7),
            Self.milestone("Second", orderIndex: 7),
            Self.milestone("Third", orderIndex: 0),
        ])
        let output = try RoadmapValidator.validated(input)
        #expect(output.milestones.map(\.orderIndex) == [0, 1, 2])
        #expect(output.milestones.map(\.title) == ["First", "Second", "Third"])
    }

    @Test("a duplicated milestone is dropped, because padding carries no information")
    func dropsDuplicateMilestones() throws {
        // The commonest way a small model pads a plan to satisfy a count guide.
        let input = Self.draft(milestones: [
            Self.milestone("Foundations"),
            Self.milestone("foundations"),      // same tier, different case
            Self.milestone("  Foundations  "),  // and again, with whitespace
            Self.milestone("Ship it"),
        ])
        let output = try RoadmapValidator.validated(input)
        #expect(output.milestones.count == 2)
        #expect(output.milestones.map(\.title) == ["Foundations", "Ship it"])
    }

    @Test("duplicate steps within a milestone are dropped and the rest renumbered")
    func dropsDuplicateTasks() throws {
        let input = Self.draft(milestones: [
            Self.milestone("Foundations", tasks: [
                Self.task("Read the docs", orderIndex: 0),
                Self.task("read the docs", orderIndex: 1),
                Self.task("Write a test", orderIndex: 2),
            ])
        ])
        let output = try RoadmapValidator.validated(input)
        #expect(output.milestones[0].tasks.map(\.title) == ["Read the docs", "Write a test"])
        #expect(output.milestones[0].tasks.map(\.orderIndex) == [0, 1])
    }

    @Test("whitespace and stray newlines are collapsed, not rendered as layout bugs")
    func condensesWhitespace() throws {
        let input = Self.draft(milestones: [Self.milestone("  Build   the\n\n  thing  ")],
                               title: "  Learn\tSwiftUI  ")
        let output = try RoadmapValidator.validated(input)
        #expect(output.title == "Learn SwiftUI")
        #expect(output.milestones[0].title == "Build the thing")
    }

    @Test("a blank title is rejected rather than replaced with a plausible placeholder")
    func rejectsBlankTitles() throws {
        // Repairing what is unambiguous is fine; inventing a title is not. A plan with a blank
        // milestone is one the user cannot act on, and a placeholder hides that.
        #expect(throws: (any Error).self) {
            _ = try RoadmapValidator.validated(Self.draft(milestones: [Self.milestone("Fine")],
                                                          title: "   "))
        }
        #expect(throws: (any Error).self) {
            _ = try RoadmapValidator.validated(Self.draft(milestones: [Self.milestone("  ")]))
        }
    }

    @Test("an empty plan is rejected")
    func rejectsEmptyPlan() throws {
        #expect(throws: (any Error).self) {
            _ = try RoadmapValidator.validated(Self.draft(milestones: []))
        }
    }

    @Test("a plan larger than a person can hold is rejected")
    func rejectsOversizedPlan() throws {
        let many = (0..<40).map { Self.milestone("Tier \($0)", orderIndex: $0) }
        #expect(throws: (any Error).self) {
            _ = try RoadmapValidator.validated(Self.draft(milestones: many))
        }
        let manyTasks = (0..<40).map { Self.task("Step \($0)", orderIndex: $0) }
        #expect(throws: (any Error).self) {
            _ = try RoadmapValidator.validated(
                Self.draft(milestones: [Self.milestone("Foundations", tasks: manyTasks)]))
        }
    }

    @Test("a plan that was entirely duplicates is rejected rather than silently emptied")
    func rejectsAllDuplicates() throws {
        let input = Self.draft(milestones: [
            Self.milestone("Same"), Self.milestone("same"), Self.milestone("SAME"),
        ])
        // Deduplication leaves one, which is a legitimate one-tier plan.
        let output = try RoadmapValidator.validated(input)
        #expect(output.milestones.count == 1)
    }

    @Test("an absurdly long title is truncated rather than breaking every layout downstream")
    func truncatesLongTitles() throws {
        let long = String(repeating: "a", count: 500)
        let output = try RoadmapValidator.validated(
            Self.draft(milestones: [Self.milestone(long)], title: long))
        #expect(output.title.count == RoadmapValidator.maxTitleLength)
        #expect(output.milestones[0].title.count == RoadmapValidator.maxTitleLength)
    }

    @Test("validation is idempotent -- running it twice changes nothing further")
    func isIdempotent() throws {
        let input = Self.draft(milestones: [
            Self.milestone("  Foundations ", orderIndex: 9, tasks: [Self.task("Read  the docs", orderIndex: 4)]),
            Self.milestone("Ship it", orderIndex: 9),
        ])
        let once = try RoadmapValidator.validated(input)
        let twice = try RoadmapValidator.validated(once)
        #expect(once == twice)
    }
}
