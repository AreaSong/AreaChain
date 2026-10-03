import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchObjectContractTests {
    @Test func singleAndParentUseDifferentAuthoritativeFields() async throws {
        for command in ["todo.title", "subtask.create"] {
            let fixture = try UnifiedSearchResultsFixture(.objectBatch())
            defer { fixture.stop() }
            try fixture.startOperation(command)
            try fixture.typeParameter(.title, text: "保留参数")
            let before = try fixture.draft
            let location: UnifiedSearchObjectLocation = command == "todo.title" ? .targets : .parameter(.parent)
            try await fixture.acceptObjects([.object(0)], location: location)
            let after = try fixture.draft
            #expect(after.id == before.id)
            #expect(after.version > before.version)
            #expect(after.arguments.contains { $0.parameter == .title && $0.value == .shortText("保留参数") })
            if location == .targets {
                #expect(after.targets.objects == [.object(0)])
                #expect(!after.arguments.contains { $0.parameter == .target })
            } else {
                #expect(after.targets == .none)
                #expect(after.arguments.contains { $0.parameter == .parent && $0.value == .object(.object(0)) })
            }
            #expect(!after.check().isExecutable)
            #expect(try fixture.handoff.owned().session.plan.items.isEmpty)
            #expect(try fixture.handoff.owned().session.execution == nil)
        }
    }

    @Test func batchRestrictionDoesNotSilentlyNarrowAndCancelPreservesDraft() async throws {
        for command in ["todo.title", "todo.completion"] {
            let fixture = try UnifiedSearchResultsFixture(.objectBatch())
            defer { fixture.stop() }
            try fixture.startOperation(command)
            let before = try fixture.draft
            let picker = try await fixture.chooseObjects()
            fixture.controller.toggleObject(.object(0), stamp: picker.stamp)
            fixture.controller.toggleObject(.object(1), stamp: picker.stamp)
            #expect(try fixture.draft == before)
            let accepted = fixture.controller.acceptObjects(picker.stamp)
            #expect(accepted == (command == "todo.completion"))
            if !accepted {
                #expect(fixture.controller.objectSelection?.objects.count == 2)
                #expect(fixture.controller.objectSelectionMessage == "unified.objects.singleOnly")
                fixture.controller.cancelObjectSelection()
                #expect(try fixture.draft == before)
            } else { #expect(try fixture.draft.targets.objects.count == 2) }
        }
    }

    @Test func displayedAndKnownFreezeExactSetsAcrossLaterLoading() async throws {
        for all in [false, true] {
            let fixture = try UnifiedSearchResultsFixture(.objectBatch(), pageSize: 2)
            defer { fixture.stop() }
            try fixture.startOperation("todo.completion")
            let picker = try await fixture.chooseObjects()
            fixture.controller.browseObjects(all ? .selectAllKnown : .selectVisible, stamp: picker.stamp)
            try #require(fixture.controller.acceptObjects(picker.stamp))
            await fixture.controller.objectSelectionTask?.value
            let fixed = try fixture.draft.targets
            #expect(fixed.objects.count == (all ? 6 : 2))
            #expect(fixed.selection == (all ? .allResults : .selected))
            fixture.batch = .objectBatch(count: 9)
            _ = try await fixture.publish()
            #expect(try fixture.draft.targets == fixed)
            #expect(try fixture.page.snapshot.known.count == 9)
        }
    }

    @Test func sameUUIDAndParentRelationRemainTyped() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        try fixture.startOperation("subtask.completion")
        let child = CommandObjectReference(type: .subtask, id: QueryBatchFixture.id)
        let parent = CommandObjectReference(type: .todo, id: QueryBatchFixture.id)
        let picker = try await fixture.chooseObjects()
        fixture.controller.toggleObject(parent, stamp: picker.stamp)
        fixture.controller.toggleObject(child, stamp: picker.stamp)
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(fixture.controller.objectSelection?.objects.count == 2)
        fixture.controller.toggleObject(parent, stamp: picker.stamp)
        try #require(fixture.controller.acceptObjects(picker.stamp))
        await fixture.controller.objectSelectionTask?.value
        #expect(try fixture.draft.targets.objects == [child])
        #expect(fixture.controller.objectPreview(child)?.relations.first?.object == parent)
    }

    @Test func baselineIsFreshExplicitEvidenceAndParametersSurvive() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let command = CommandID(rawValue: "todo.title")
        fixture.controller.syntheticBaselines[command] = .init([
            .init(subject: .object(.object(0)), parameter: .title): .uniform(.shortText("原值"))])
        try fixture.startOperation(command.rawValue)
        try await fixture.acceptObjects([.object(0)])
        try fixture.typeParameter(.title, text: "我的修改")
        #expect(try fixture.draft.baseline.original(.title, targets: fixture.draft.targets) == .uniform(.shortText("原值")))
        fixture.controller.syntheticBaselines[command] = nil
        try await fixture.acceptObjects([.object(1)])
        #expect(try fixture.draft.baseline.values.isEmpty)
        #expect(try fixture.draft.arguments.first?.value == .shortText("我的修改"))
        fixture.controller.removeObject(.object(1), location: .targets, source: fixture.controller.buffer)
        #expect(try fixture.draft.targets == .none)
        #expect(try fixture.draft.arguments.first?.value == .shortText("我的修改"))
    }
}
