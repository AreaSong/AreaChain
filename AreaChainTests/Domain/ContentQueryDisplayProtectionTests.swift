import Foundation
import Testing
@testable import AreaChain

struct ContentQueryDisplayProtectionTests {
    @Test func hiddenDiaryHasNoBodyControlsAndProtectedImageHasNoIdentity() throws {
        for trash in [false, true] {
            var batch = QueryBatchFixture.mixed(trash ? "/trash" : "")
            var diary = batch.snapshots.diaries.values![0]
            diary.isPrivate = true
            diary.text = String(repeating: "SYNTHETIC_PRIVATE_BODY", count: 100)
            diary.deletedAt = trash ? TrashFixture.date : nil
            batch.snapshots.diaries = .complete([diary])
            var attachment = batch.snapshots.images.values![0]
            attachment.protection = .protected
            attachment.deletedAt = trash ? TrashFixture.date : nil
            batch.snapshots.images = .complete([attachment])
            let snapshot = QueryDisplayFixture.display(batch)
            let id = try #require(snapshot.visible.first { $0.type == .diary })
            var state = ContentQueryBrowseState(snapshot: snapshot)
            #expect(snapshot.visible.allSatisfy { $0.type != .image })
            #expect(snapshot.units.flatMap(\.context).allSatisfy { $0.object.type != .image })
            #expect(state.toggleControls.allSatisfy {
                if case .bodyToggle(let object, _) = $0 { return object != id }; return true
            })
            let result = state.apply(QueryDisplayFixture.event(state, .expand(.bodyToggle(id, .diaryBody))))
            #expect(result.rejection == .invalidTarget)
            let redacted = !TrashQueryFixture.strings(snapshot).contains("SYNTHETIC_PRIVATE_BODY")
            #expect(redacted)
        }
    }

    @Test func hiddenOwnerImageCannotCreateContext() {
        var batch = QueryBatchFixture.empty("/trash type:image")
        var diary = TrashFixture.diary()
        diary.isPrivate = true
        batch.snapshots.diaries = .complete([diary])
        batch.snapshots.images = .complete([TrashFixture.image(owner: .diary)])
        let snapshot = QueryDisplayFixture.display(batch)
        #expect(snapshot.units.isEmpty && snapshot.known.isEmpty)
        #expect(snapshot.source.rows.isEmpty)
    }

    @Test func reviewAndUnknownAreNotKnownVisibleActiveOrSelectable() {
        var batch = QueryBatchFixture.occurrences()
        batch.facts.routine.scheduleEvidence = []
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)]
        let snapshot = QueryDisplayFixture.display(batch)
        #expect(snapshot.source.source.source.completeness.providers[0].limitations.contains(.reviewRecords))
        #expect(snapshot.visible.isEmpty && snapshot.known.isEmpty)
        var state = ContentQueryBrowseState(snapshot: snapshot)
        _ = state.apply(QueryDisplayFixture.event(state, .selectAllKnown))
        #expect(state.selected.isEmpty && state.active == nil)
        let id = CommandObjectReference(type: .routineOccurrence, id: QueryBatchFixture.id, dayKey: QuerySessionFixture.today)
        #expect(state.apply(QueryDisplayFixture.event(state, .activate(id))).rejection == .invalidTarget)
        #expect(state.apply(QueryDisplayFixture.event(state, .open(inputEditing: false))).open == nil)
    }

    @Test func parserThroughSelectionKeepsCoverageAndSafeSource() {
        var batch = QueryBatchFixture.mixed("(batch-common | absent) -excluded")
        batch.snapshots.todos = .partial(batch.snapshots.todos.values!)
        let presentation = QueryPresentationFixture.project(batch)
        let snapshot = ContentQueryDisplayBuilder.build(presentation)
        var state = ContentQueryBrowseState(snapshot: snapshot)
        _ = state.apply(QueryDisplayFixture.event(state, .selectVisible))
        #expect(state.selected == Set(presentation.source.ordered.map(\.id)))
        #expect(snapshot.source.source.source.completeness == presentation.source.source.completeness)
        #expect(snapshot.source.source.source.matches == presentation.source.source.matches)
        #expect(snapshot.source.source.onlyKnownSubset)
    }
}
