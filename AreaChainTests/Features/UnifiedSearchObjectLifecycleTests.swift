import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchObjectLifecycleTests {
    @Test func returnWhileLoadingDoesNotRestartDraftOrInvalidatePendingRead() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.title")
        fixture.controller.beginObjectSelection(.targets, source: fixture.controller.buffer)
        let source = fixture.controller.buffer
        let draft = try fixture.draft
        fixture.controller.intent(.open, source: source)
        fixture.controller.intent(.results(1), source: source)
        #expect(fixture.controller.buffer == source)
        #expect(try fixture.draft == draft)
        await fixture.controller.objectSelectionTask?.value
        let picker = try #require(fixture.controller.objectSelection)
        #expect(fixture.controller.validatesObjectSelection(picker.stamp))
    }

    @Test func cancelledReadAndOldCancelCannotCloseNewPicker() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.title")
        fixture.controller.beginObjectSelection(.targets, source: fixture.controller.buffer)
        let oldRequest = fixture.controller.objectRequestID
        let oldTask = fixture.controller.objectSelectionTask
        fixture.controller.cancelObjectSelection()
        let picker = try await fixture.chooseObjects()
        await oldTask?.value
        fixture.controller.cancelObjectSelection(expecting: oldRequest)
        #expect(fixture.controller.objectSelection?.stamp == picker.stamp)
        #expect(fixture.controller.validatesObjectSelection(picker.stamp))
        #expect(try fixture.draft.targets == .none)
    }

    @Test func reviewRecordsAndPartialReadsAreNotPromotedToAllData() async throws {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-02")
        batch.snapshots.diaries = .complete([])
        batch.facts.routine.scheduleEvidence = []
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)]
        let fixture = try UnifiedSearchResultsFixture(batch)
        defer { fixture.stop() }
        try fixture.startOperation("occurrence.reopen")
        let picker = try await fixture.chooseObjects()
        #expect(picker.browse.snapshot.known.isEmpty)
        #expect(try !fixture.session.presentation().response.completeness.matchingIsComplete)
        fixture.controller.browseObjects(.selectAllKnown, stamp: picker.stamp)
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(try fixture.draft.targets == .none)
    }

    @Test func oldCandidateDraftAndPositionCannotAccept() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.title")
        let picker = try await fixture.chooseObjects()
        fixture.controller.toggleObject(.object(0), stamp: picker.stamp)
        _ = try await fixture.publish()
        let before = try fixture.draft
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(try fixture.draft == before)
        fixture.controller.cancelObjectSelection()
        let next = try await fixture.chooseObjects()
        fixture.controller.toggleObject(.object(0), stamp: next.stamp)
        try fixture.typeParameter(.title, text: "新版本")
        let changed = try fixture.draft
        #expect(!fixture.controller.acceptObjects(next.stamp))
        #expect(try fixture.draft == changed)
        #expect(changed.targets == .none)
    }

    @Test func paginationRejectsOldConfirmationAndDoesNotGrowTemporarySelection() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch(), pageSize: 2)
        defer { fixture.stop() }
        try fixture.startOperation("todo.completion")
        let picker = try await fixture.chooseObjects()
        fixture.controller.browseObjects(.selectVisible, stamp: picker.stamp)
        fixture.controller.loadObjectCandidates(picker.stamp)
        let next = try #require(fixture.controller.objectSelection)
        #expect(next.browse.snapshot.visible.count == 4)
        #expect(next.objects.count == 2)
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(fixture.controller.acceptObjects(next.stamp))
        #expect(try fixture.draft.targets.objects.count == 2)
    }

    @Test func maskFocusAndTransferDropCandidateReferencesAndRejectLease() async throws {
        for event in 0..<3 {
            let fixture = try UnifiedSearchResultsFixture(.objectBatch())
            defer { fixture.stop() }
            try fixture.startOperation("todo.title")
            try fixture.typeParameter(.title, text: "保留草稿")
            let picker = try await fixture.chooseObjects()
            fixture.controller.toggleObject(.object(0), stamp: picker.stamp)
            let before = try fixture.draft
            switch event {
            case 0: NotificationCenter.default.post(name: .privacyWillLock, object: fixture.vault)
            case 1: try fixture.session.loseFocus(expecting: picker.source.lease.ownership)
            default: _ = try fixture.handoff.transfer()
            }
            #expect(fixture.controller.objectSelection == nil)
            #expect(!fixture.session.hasRetainedPresentation)
            #expect(!fixture.controller.acceptObjects(picker.stamp))
            if event == 2 {
                let moved = try #require(fixture.handoff.state(HandoffFixture.target).operations.active)
                #expect(moved.arguments == before.arguments && moved.targets == before.targets)
                #expect(fixture.controller.operations == nil)
            } else { #expect(try fixture.draft == before) }
        }
    }

    @Test func removedObjectIsNotReplacedAndQueryChangesKeepFixedTargets() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation("todo.title")
        try await fixture.acceptObjects([.object(0)])
        let fixed = try fixture.draft.targets
        var batch = ContentQueryBatch.objectBatch(count: 0)
        batch.snapshots.todos = .complete([.init(id: UnifiedSearchResultsFixture.objectID(50),
            title: "合成任务 0", isDone: false, dayKey: QuerySessionFixture.today, createdAt: TodoQueryFixture.created)])
        fixture.batch = batch
        _ = try await fixture.publish()
        #expect(fixture.controller.objectPreview(.object(0)) == nil)
        #expect(try fixture.draft.targets == fixed)
        let source = fixture.controller.buffer
        #expect(fixture.controller.edit(.init(source: source, text: "", selection: .init(location: 0, length: 0))) != nil)
        #expect(try fixture.draft.targets == fixed)
        fixture.controller.operationExpanded = false
        #expect(try fixture.draft.targets == fixed)
    }

    @Test func unsupportedMatchesContextsAndUnknownNeverBecomeCandidates() async throws {
        for batch in [UnifiedSearchResultsFixture.mixed(), QueryBatchFixture.trash()] {
            let fixture = try UnifiedSearchResultsFixture(batch, pageSize: 20)
            defer { fixture.stop() }
            try fixture.startOperation("todo.completion")
            let picker = try await fixture.chooseObjects()
            fixture.controller.browseObjects(.selectAllKnown, stamp: picker.stamp)
            let selected = try #require(fixture.controller.objectSelection)
            #expect(selected.browse.selected == selected.browse.snapshot.known)
            for context in selected.browse.snapshot.units.flatMap(\.context) {
                #expect(!selected.browse.selected.contains(context.object))
                #expect((try? fixture.session.objectCandidate(context.object,
                    sourceID: selected.browse.snapshot.sourceID)) == nil)
            }
            #expect(!fixture.controller.acceptObjects(picker.stamp))
            #expect(try fixture.draft.targets == .none)
        }
    }

    @Test func ordinaryObjectsParameterUsesValueArrayAndDomainClearsOldBaseline() throws {
        let command = CommandDescriptorForObjects.make()
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let argument = fixture.controller.objectArgument(.parameter(.parent), objects: [.object(0), .object(1)], command: command)
        #expect(argument?.parameter == .parent)
        #expect(argument?.value == .objects([.object(0), .object(1)]))
        var state = DraftFixture.session()
        let baseline = DraftFixture.baseline(.object(0), .title, .uniform(.shortText("old")))
        DraftFixture.apply(.start(expectedRevision: 0, DraftFixture.draft("todo.title",
            targets: .init(.single, objects: [.object(0)]), baseline: baseline)), to: &state)
        DraftFixture.edit(.init(parameter: .title, operation: .assign, value: .shortText("edited")), in: &state)
        let stamp = try #require(state.active?.stamp)
        DraftFixture.apply(.selectTargets(stamp, .init(.single, objects: [.object(1)])), to: &state)
        #expect(state.active?.baseline.values.isEmpty == true)
        #expect(state.active?.arguments.first?.value == .shortText("edited"))
    }
}

private enum CommandDescriptorForObjects {
    static func make() -> CommandDescriptor {
        var command = CommandCatalog.standard.command(id: .init(rawValue: "subtask.create"))!
        command.parameters = [.init(id: .parent, type: .objects([.todo]))]
        return command
    }
}
