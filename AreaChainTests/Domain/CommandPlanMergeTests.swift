import Foundation
import Testing
@testable import AreaChain

struct CommandPlanMergeTests {
    @Test func malformedBaselineCannotProveEquivalentAssignment() throws {
        var host = PlanFixture.host()
        let baseline = CommandDraftBaseline([.init(subject: .ambient, parameter: .value): .uniform(.number(1))])
        for value in ["chinese", "english"] {
            let draft = CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "setting.language"),
                                     baseline: baseline, arguments: [PlanFixture.argument(.value, .choice(value))])
            try PlanFixture.queue(draft, in: &host)
        }
        #expect(throws: CommandPlanError.mergeConflict(.baseline)) {
            try host.planEvent(.merge(earlier: host.plan.items[0].stamp, later: host.plan.items[1].stamp), expecting: host.plan.stamp)
        }
        #expect(host.plan.items.count == 2)
    }

    @Test func fixedTargetAssignmentMergesButTitleParsingRemainsConservative() throws {
        let object = CommandObjectReference(type: .todo, id: UUID())
        for (command, parameter, values) in [
            ("todo.priority", CommandParameterID.priority, [CommandValue.choice("p1"), .choice("p2")]),
            ("todo.title", .title, [.shortText("Synthetic #tag"), .shortText("Synthetic title")])
        ] {
            var host = PlanFixture.host()
            let baseline = CommandDraftBaseline([.init(subject: .object(object), parameter: parameter): .uniform(values[0])])
            for value in values {
                let draft = CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: command),
                                         targets: .init(.single, objects: [object]), baseline: baseline,
                                         arguments: [PlanFixture.argument(parameter, value)])
                try PlanFixture.queue(draft, in: &host)
            }
            let event = CommandPlanEvent.merge(earlier: host.plan.items[0].stamp, later: host.plan.items[1].stamp)
            if parameter == .priority {
                try host.planEvent(event, expecting: host.plan.stamp)
                #expect(host.plan.items.count == 1 && host.plan.items[0].draft.baseline == baseline)
                #expect(host.plan.items[0].draft.arguments[0].value == values[1])
            } else {
                #expect(throws: CommandPlanError.mergeConflict(.sequentialOperation)) { try host.planEvent(event, expecting: host.plan.stamp) }
            }
        }
    }

    @Test func equivalentAssignmentKeepsInitialIdentityBaselineAndFinalValue() throws {
        var host = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        let last = try PlanFixture.queue(PlanFixture.setting("english"), in: &host)
        let original = try PlanFixture.item(first, in: host), final = try PlanFixture.item(last, in: host)
        try host.planEvent(.merge(earlier: original.stamp, later: final.stamp), expecting: host.plan.stamp)
        #expect(host.plan.items.count == 1)
        #expect(host.plan.items[0].draft.id == original.draft.id)
        #expect(host.plan.items[0].draft.baseline == original.draft.baseline)
        #expect(host.plan.items[0].draft.arguments == final.draft.arguments)
        #expect(host.plan.items[0].mergedOrigins == [final.draft.stamp])
        #expect(host.operations.active == nil && host.operations.retained.isEmpty)
        try host.removeFromPlan(host.plan.items[0].stamp, expecting: host.plan.stamp)
        #expect(host.operations.retained[0].arguments == final.draft.arguments)
    }

    @Test func differentSettingWithSameParameterAndIncompatibleBaselineDoNotMerge() throws {
        for draft in [PlanFixture.setting("dark", command: "setting.appearance"),
                      CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "setting.language"),
                                   arguments: [PlanFixture.argument(.value, .choice("english"))])] {
            var host = PlanFixture.host()
            try PlanFixture.queue(PlanFixture.setting(), in: &host)
            try PlanFixture.queue(draft, in: &host)
            let before = host
            #expect(throws: CommandPlanError.self) {
                try host.planEvent(.merge(earlier: host.plan.items[0].stamp, later: host.plan.items[1].stamp), expecting: host.plan.stamp)
            }
            #expect(host == before)
        }
    }

    @Test func appendPartialOverlapAndAnyDependencyNeverMerge() throws {
        var host = PlanFixture.host()
        let target = CommandObjectReference(type: .todo, id: UUID())
        for _ in 0..<2 {
            let draft = CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "todo.notes"),
                                     targets: .init(.single, objects: [target]),
                                     arguments: [.init(parameter: .notes, operation: .append, value: .longText("Synthetic append"))])
            try PlanFixture.queue(draft, in: &host)
        }
        #expect(throws: CommandPlanError.mergeConflict(.sequentialOperation)) {
            try host.planEvent(.merge(earlier: host.plan.items[0].stamp, later: host.plan.items[1].stamp), expecting: host.plan.stamp)
        }
        var overlap = PlanFixture.host()
        for objects in [[target], [target, .init(type: .todo, id: UUID())]] {
            let draft = CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "todo.priority"),
                                     targets: .init(.selected, objects: objects),
                                     arguments: [PlanFixture.argument(.priority, .choice("p1"))])
            try PlanFixture.queue(draft, in: &overlap)
        }
        #expect(throws: CommandPlanError.mergeConflict(.targets)) {
            try overlap.planEvent(.merge(earlier: overlap.plan.items[0].stamp, later: overlap.plan.items[1].stamp), expecting: overlap.plan.stamp)
        }
        var dependent = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.setting(), in: &dependent)
        let last = try PlanFixture.queue(PlanFixture.setting("english"), in: &dependent)
        try PlanFixture.link(last, to: [first], in: &dependent)
        #expect(throws: CommandPlanError.mergeConflict(.dependency)) {
            try dependent.planEvent(.merge(earlier: dependent.plan.items[0].stamp, later: dependent.plan.items[1].stamp), expecting: dependent.plan.stamp)
        }
        #expect(host.plan.items.count == 2 && overlap.plan.items.count == 2 && dependent.plan.items.count == 2)
    }
}
