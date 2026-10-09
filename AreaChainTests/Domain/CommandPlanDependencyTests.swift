import Foundation
import Testing
@testable import AreaChain

struct CommandPlanDependencyTests {
    @Test func confirmedPredecessorRetryUnblocksDependentsWithoutReplayingIndependentSuccess() throws {
        var host = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let child = try PlanFixture.queue(PlanFixture.child(), in: &host)
        let independent = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        try PlanFixture.reference(child, parent: first, in: &host)
        try PlanFixture.seal(&host)
        let failed = try PlanFixture.begin(&host)
        try PlanFixture.result(.failedWithoutCommit, attempt: failed, in: &host)
        let other = try PlanFixture.begin(&host)
        #expect(other.unitID == independent)
        try PlanFixture.result(.committed(outputs: [:], external: []), attempt: other, in: &host)
        try host.retryProtocolStep(failed, assurance: .safeLocalReplay)
        let retry = try PlanFixture.begin(&host)
        try PlanFixture.result(.committed(outputs: [first: .init(type: .todo, id: UUID())], external: []), attempt: retry, in: &host)
        #expect(try PlanFixture.begin(&host).unitID == child)
        #expect(host.execution?.units[2].attempt == 1 && host.execution?.units[2].state == .succeeded)
    }

    @Test func orderUnknownSelfCycleAndRemovalKeepOriginalPlan() throws {
        var host = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let last = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        try PlanFixture.link(last, to: [first], in: &host)
        let before = host
        #expect(throws: CommandPlanError.self) {
            try host.planEvent(.reorder([last, first]), expecting: host.plan.stamp)
        }
        #expect(host == before)
        #expect(throws: CommandPlanError.dependents([last])) {
            try host.removeFromPlan(PlanFixture.item(first, in: host).stamp, expecting: host.plan.stamp)
        }
        for (dependencies, expected) in [([first], CommandDependencyIssue.selfDependency(first)), ([last], .cycle)] {
            do {
                try PlanFixture.link(first, to: Set(dependencies), in: &host)
                Issue.record("应拒绝失效依赖")
            } catch CommandPlanError.graph(let issues) { #expect(issues.contains(expected)) }
            #expect(host == before)
        }
        let unknown = UUID()
        do { try PlanFixture.link(last, to: [unknown], in: &host); Issue.record("应拒绝未知依赖") }
        catch CommandPlanError.graph(let issues) { #expect(issues.contains(.unknown(item: last, predecessor: unknown))) }
        #expect(host == before)
        try PlanFixture.link(last, to: [], in: &host)
        try host.removeFromPlan(PlanFixture.item(first, in: host).stamp, expecting: host.plan.stamp)
        #expect(host.operations.retained.count == 1 && host.plan.items.count == 1)
    }

    @Test func typedCreationReferenceHasNoPlaceholderAndProducerEditInvalidatesIt() throws {
        var host = PlanFixture.host()
        let parent = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let child = try PlanFixture.queue(PlanFixture.child(), in: &host)
        try PlanFixture.reference(child, parent: parent, in: &host)
        #expect(host.plan.check().canSealProtocol)
        #expect(try PlanFixture.item(child, in: host).draft.arguments.allSatisfy { $0.parameter != .parent })
        let before = host
        let bad = CommandCreationReference(producer: try PlanFixture.item(parent, in: host).stamp, outputType: .diary)
        #expect(throws: CommandPlanError.self) {
            try host.planEvent(.link(PlanFixture.item(child, in: host).stamp, .init(results: [.parent: bad])), expecting: host.plan.stamp)
        }
        #expect(host == before)
        #expect(throws: CommandPlanError.self) { try PlanFixture.reference(child, parent: parent, parameter: .title, in: &host) }
        try PlanFixture.edit(parent, argument: PlanFixture.argument(.title, .shortText("Synthetic revision")), in: &host)
        #expect(host.plan.check().dependencies.contains(.staleReference(child, .parent)))
        #expect(throws: CommandPlanError.incomplete) { try PlanFixture.seal(&host) }
        try PlanFixture.reference(child, parent: parent, in: &host)
        #expect(host.plan.check().canSealProtocol)
        #expect(CommandCatalog.standard.entries.filter { $0.createdObjectType != nil }.map(\.id.rawValue).sorted()
            == ["routine.create", "subtask.create", "todo.create"])
    }

    @Test func outputResolvesOnlyAfterSuccessAndIsFixedAcrossConsumerRetry() throws {
        var host = PlanFixture.host()
        let parent = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let child = try PlanFixture.queue(PlanFixture.child(), in: &host)
        try PlanFixture.reference(child, parent: parent, in: &host)
        try PlanFixture.seal(&host)
        #expect(host.execution?.resolvedInput(child) == nil)
        let createAttempt = try PlanFixture.begin(&host)
        #expect(host.execution?.units[1].state == .blocked)
        let object = CommandObjectReference(type: .todo, id: UUID())
        #expect(throws: CommandExecutionError.invalidResult) {
            try PlanFixture.result(.committed(outputs: [parent: .init(type: .diary, id: UUID())], external: []), attempt: createAttempt, in: &host)
        }
        try PlanFixture.result(.committed(outputs: [parent: object], external: []), attempt: createAttempt, in: &host)
        let childAttempt = try PlanFixture.begin(&host)
        #expect(host.execution?.resolvedInput(child)?.arguments.contains(PlanFixture.argument(.parent, .object(object))) == true)
        let identity = host.execution?.operation(child)
        try PlanFixture.result(.failedWithoutCommit, attempt: childAttempt, in: &host)
        try host.retryProtocolStep(childAttempt, assurance: .safeLocalReplay)
        let retry = try PlanFixture.begin(&host)
        #expect(retry.number == childAttempt.number + 1 && retry.unitID == childAttempt.unitID)
        #expect(host.execution?.operation(child) == identity)
        #expect(host.execution?.bindings[child]?[.parent] == object)
        #expect(throws: CommandExecutionError.notRetryable) { try host.retryProtocolStep(createAttempt, assurance: .safeLocalReplay) }
        #expect(throws: CommandExecutionError.stale) {
            try PlanFixture.result(.committed(outputs: [parent: .init(type: .todo, id: UUID())], external: []), attempt: createAttempt, in: &host)
        }
        #expect(host.execution?.outputs[parent] == object)
    }

    @Test func missingOutputBlocksReferenceAndIndependentFailureDoesNotStopOthers() throws {
        for outcome in [CommandExecutionResult.failedWithoutCommit, .committed(outputs: [:], external: [])] {
            var host = PlanFixture.host()
            let parent = try PlanFixture.queue(PlanFixture.todo(), in: &host)
            let child = try PlanFixture.queue(PlanFixture.child(), in: &host)
            let independent = try PlanFixture.queue(PlanFixture.setting(), in: &host)
            try PlanFixture.reference(child, parent: parent, in: &host)
            try PlanFixture.seal(&host)
            let first = try PlanFixture.begin(&host)
            try PlanFixture.result(outcome, attempt: first, in: &host)
            #expect(host.execution?.units[1].state == .blocked)
            #expect(host.execution?.bindings[child] == nil)
            #expect(try PlanFixture.begin(&host).unitID == independent)
            #expect(host.requiresUnsavedContentHandling)
        }
    }

    @Test func createdObjectCanBeFixedTargetWithoutEditingDraftTarget() throws {
        var host = PlanFixture.host()
        let parent = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let modification = CommandDraft(id: UUID(), hostID: "workspace", commandID: .init(rawValue: "todo.title"),
                                        arguments: [PlanFixture.argument(.title, .shortText("Synthetic new title"))])
        let edit = try PlanFixture.queue(modification, in: &host)
        try PlanFixture.reference(edit, parent: parent, parameter: .target, in: &host)
        try PlanFixture.seal(&host)
        let object = CommandObjectReference(type: .todo, id: UUID()), attempt = try PlanFixture.begin(&host)
        try PlanFixture.result(.committed(outputs: [parent: object], external: []), attempt: attempt, in: &host)
        _ = try PlanFixture.begin(&host)
        #expect(host.execution?.resolvedInput(edit)?.targets.objects == [object])
        #expect(host.execution?.snapshot.items.last?.draft.targets.objects.isEmpty == true)
    }
}
