import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchCompositionContractTests {
    @Test func previewAndAcceptanceAreReadOnlyAndVersionBound() throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let tombstone = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #new #restore")
        let id = fixture.controller.operations?.active?.id
        fixture.controller.prepareTaskComposition(fixture.controller.buffer)
        let preview = try #require(fixture.controller.currentTaskComposition)
        #expect(preview.binding.draft.draftID == id)
        #expect(fixture.controller.operations?.active == nil && fixture.controller.plan?.items.count == 1)
        fixture.controller.acceptTaskComposition(preview, source: fixture.controller.buffer)
        let accepted = try #require(fixture.controller.currentTaskAcceptance)
        #expect(accepted.tagCreationIDs.count == 1 && tombstone.deletedAt != nil)
        try fixture.noCompositionWrites()
        fixture.controller.acceptTaskComposition(preview, source: fixture.controller.buffer)
        #expect(fixture.controller.currentTaskAcceptance == accepted)
        try fixture.editComposition(.init(parameter: .priority, operation: .clear))
        #expect(fixture.controller.currentTaskAcceptance == nil && fixture.controller.currentTaskComposition == nil)
        fixture.submit()
        try fixture.noCompositionWrites()
        fixture.controller.prepareTaskComposition(fixture.controller.buffer)
        let changed = try #require(fixture.controller.currentTaskComposition)
        fixture.controller.acceptTaskComposition(changed, source: fixture.controller.buffer)
        #expect(fixture.controller.currentTaskAcceptance == nil)
        #expect(fixture.controller.compositionFailure == "unified.composition.stale")
    }

    @Test(arguments: [0, 1, 2, 3, 4]) func oldAcceptanceRejectsCatalogOrSourceChanges(kind: Int) throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let tag = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #restore #new")
        fixture.controller.prepareTaskComposition(fixture.controller.buffer)
        let preview = try #require(fixture.controller.currentTaskComposition)
        fixture.controller.acceptTaskComposition(preview, source: fixture.controller.buffer)
        let old = fixture.controller.buffer
        let original = fixture.controller.plan
        switch kind {
        case 0: tag.name = "renamed"
        case 1: tag.deletedAt = nil
        case 2: tag.isPrivateDiary = true
        case 3: fixture.io.capture.context.insert(TagItem(name: "new", sortOrder: 1))
        default: fixture.io.capture.source = "synthetic.changed"
        }
        if kind != 4 { try fixture.io.capture.context.save() }
        #expect(fixture.controller.currentTaskComposition == nil && fixture.controller.currentTaskAcceptance == nil)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.controller.plan == original)
        try fixture.noCompositionWrites()
    }

    @Test func pickerRejectsUnsafeCandidatesAndStalePosition() throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let live = try fixture.seedTag("live")
        _ = try fixture.seedTag("private", privateTag: true)
        _ = try fixture.seedTag(DiaryMemoTags.idea)
        _ = try fixture.seedTag("ambiguous")
        _ = try fixture.seedTag("AMBIGUOUS", deleted: true)
        try fixture.start()
        fixture.controller.beginTagSelection(source: fixture.controller.buffer)
        let picker = try #require(fixture.controller.tagSelection)
        #expect(picker.candidates.records.compactMap(\.id) == [live.id])
        fixture.controller.toggleTag(live.id, picker: picker)
        #expect(fixture.controller.operations?.active?.arguments.contains { $0.parameter == .tags } == false)
        fixture.controller.cancelTags(picker.id)
        #expect(fixture.controller.operations?.active?.arguments.contains { $0.parameter == .tags } == false)
        fixture.controller.beginTagSelection(source: fixture.controller.buffer)
        let stale = try #require(fixture.controller.tagSelection)
        _ = fixture.controller.editParameter(.init(parameter: .priority, operation: .clear), source: fixture.controller.buffer)
        fixture.controller.acceptTags(stale)
        #expect(fixture.controller.operations?.active?.arguments.contains { $0.parameter == .tags } == false)
        try fixture.noCompositionWrites()
    }

    @Test func incompleteCatalogAndOtherCommandsDoNotGainTagEditing() throws {
        let candidate = CommandTaskTagCatalog(directoryID: UUID(), readID: UUID(), revision: 0, coverage: .partial, records: [])
        #expect(throws: CommandTaskCreatePreviewIssue.invalidCatalog) { try CommandTaskTagCandidates(catalog: candidate) }
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        try fixture.results.startOperation("diary.tags")
        fixture.controller.beginTagSelection(source: fixture.controller.buffer)
        #expect(fixture.controller.tagSelection == nil)
        #expect(fixture.controller.editParameter(.init(parameter: .tags, operation: .clear), source: fixture.controller.buffer) == nil)
    }

    @Test(arguments: [0, 1, 2]) func submittedFactsReportOnlyCommittedTagEffects(kind: Int) throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        _ = try fixture.seedTag("live")
        let restored = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #live #new #restore @09:30")
        fixture.controller.prepareTaskComposition(fixture.controller.buffer)
        let preview = try #require(fixture.controller.currentTaskComposition)
        fixture.controller.acceptTaskComposition(preview, source: fixture.controller.buffer)
        let accepted = try #require(fixture.controller.currentTaskAcceptance)
        try fixture.noCompositionWrites()
        #expect(restored.deletedAt != nil)
        if kind == 1 { fixture.io.saveMode = .throwAfter }
        if kind == 2 { fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        fixture.io.authorizationResult = .denied
        fixture.submit()
        let facts = try fixture.facts
        #expect(facts.state == (kind == 1 ? .unknown : .saved))
        #expect(facts.savedTagEffects == (kind == 1 ? nil : [.associateLive, .createAndAssociate, .restoreAndAssociate]))
        #expect(facts.savedID == (kind == 1 ? nil : accepted.creationID))
        #expect(try fixture.io.capture.readTodos().count == 1 && fixture.readTags().count == 3)
        #expect(fixture.count("save") == 1 && restored.deletedAt == nil)
        #expect(fixture.count("ui") == (kind == 0 ? 1 : 0))
        #expect(fixture.io.capture.authorizations == (kind == 1 ? [] : [570]))
        if kind != 1 { #expect(facts.authorizationRequest == .returned && facts.authorizationResult == .denied) }
        fixture.submit()
        #expect(fixture.count("save") == 1)
    }
}
