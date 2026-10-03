import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPresentationProtectionTests {
    @Test func allTrashFieldBranchesKeepSafeMainAndHiddenBodyAbsence() {
        var batch = QueryBatchFixture.mixed("/trash")
        let stamp = TodoQueryFixture.created + 100
        batch.snapshots.todos = .complete(batch.snapshots.todos.values!.map { var value = $0; value.deletedAt = stamp; return value })
        batch.snapshots.subtasks = .complete(batch.snapshots.subtasks.values!.map { var value = $0; value.deletedAt = stamp; return value })
        batch.snapshots.routines = .complete(batch.snapshots.routines.values!.map { var value = $0; value.deletedAt = stamp; return value })
        batch.snapshots.tags = .complete(batch.snapshots.tags.values!.map { var value = $0; value.deletedAt = stamp; return value })
        batch.snapshots.images = .complete(batch.snapshots.images.values!.map { var value = $0; value.deletedAt = stamp; return value })
        var diary = batch.snapshots.diaries.values![0]
        diary.deletedAt = stamp
        diary.isPrivate = true
        diary.text = "SYNTHETIC_TRASH_HIDDEN_BODY"
        batch.snapshots.diaries = .complete([diary])
        let result = QueryPresentationFixture.project(batch)
        #expect(result.rows.count == 6)
        #expect(result.rows.allSatisfy { $0.primary != nil })
        let hidden = result.rows.first { $0.id.type == .diary }
        #expect(hidden?.summary == nil && hidden?.canRequestExpansion == false && hidden?.omittedPublicContent == false)
        let hidesBody = !TrashQueryFixture.strings(result).contains(diary.text)
        #expect(hidesBody)
    }

    @Test func identicalPublicProjectionIgnoresHiddenBodyChangesInBothLanguages() throws {
        for locale in [Locale(identifier: "en"), Locale(identifier: "zh-Hans")] {
            var batch = QueryBatchFixture.mixed("batch-common")
            batch.options.locale = locale
            var diary = batch.snapshots.diaries.values![0]
            diary.isPrivate = true
            var observed: [ContentQueryPresentationRow] = []
            for text in ["batch-common", "batch-common\n" + String(repeating: "SYNTHETIC_PRIVATE_BODY", count: 100)] {
                diary.text = text
                batch.snapshots.diaries = .complete([diary])
                let result = ContentQueryPresenter.project(QuerySortFixture.sort(batch), budget: QueryPresentationFixture.budget, locale: locale)
                let row = try #require(result.rows.first { $0.id.type == .diary })
                let usesHiddenTitle = row.primary?.text == L10n.string("diary.private.title", locale: locale)
                #expect(usesHiddenTitle)
                #expect(row.primary?.mapping == nil && row.primary?.highlights.isEmpty == true)
                #expect(row.summary == nil && !row.omittedPublicContent && !row.canRequestExpansion)
                let hidesBody = !TrashQueryFixture.strings(row).contains("SYNTHETIC_PRIVATE_BODY")
                #expect(hidesBody)
                observed.append(row)
            }
            #expect(observed[0] == observed[1])
        }
    }

    @Test func protectedImagesAndOwnerNamesAreNotRecoveredFromBatch() throws {
        var batch = QueryBatchFixture.mixed("")
        var todo = batch.snapshots.todos.values![0]
        todo.title = "SYNTHETIC_OWNER_TITLE"
        batch.snapshots.todos = .complete([todo])
        let result = QueryPresentationFixture.project(batch)
        let image = try #require(result.rows.first { $0.id.type == .image })
        #expect(image.relations.first?.title == nil)
        let hidesOwnerName = !TrashQueryFixture.strings(image).contains(todo.title)
        #expect(hidesOwnerName)
        var imageInput = batch.snapshots.images.values![0]
        imageInput.protection = .protected
        batch.snapshots.images = .complete([imageInput])
        #expect(QueryPresentationFixture.project(batch).rows.allSatisfy { $0.id.type != .image })
    }

    @Test func trashContextNeverBecomesMatchOrExpansionTarget() throws {
        let result = QueryPresentationFixture.project(QueryBatchFixture.trash("/trash 合成子任务"))
        guard case .trash(let trash) = result.source.source.readings[0] else { Issue.record("夹具缺少墓碑"); return }
        #expect(result.rows.count == 1 && trash.visibleContextCount == 2)
        #expect(result.rows.map(\.id) == trash.matches.map(\.id))
        #expect(result.rows[0].relations.first?.role == .parentTask)
        #expect(result.rows[0].expansion.isEmpty)
        #expect(!result.rows.contains { row in trash.groups[0].context.contains { $0.id == row.id } })
    }

    @Test func parserThroughPresentationPreservesSortingCountsAndCompleteness() {
        var batch = QueryBatchFixture.mixed("(batch-common | absent) -excluded")
        batch.snapshots.todos = .partial(batch.snapshots.todos.values!)
        let sorted = QuerySortFixture.sort(batch)
        let result = ContentQueryPresenter.project(sorted, budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale)
        #expect(result.rows.map(\.id) == sorted.ordered.map(\.id))
        #expect(result.source.ordered == sorted.ordered && result.source.applied == sorted.applied)
        #expect(result.source.source.matches == sorted.source.matches)
        #expect(result.source.source.definiteMatchCount == sorted.source.definiteMatchCount)
        #expect(result.source.source.completeness == sorted.source.completeness)
        #expect(result.source.onlyKnownSubset && !result.source.source.canDeclareCompleteNoMatch)
    }

    @Test func nestedDescriptionsAreRedacted() {
        let result = QueryPresentationFixture.project(QueryBatchFixture.mixed())
        var strings = [String(describing: result), String(reflecting: result), String(reflecting: result.rows)]
        strings.append(String(reflecting: result.source.source.sortContext.presentationConditions))
        for row in result.rows {
            strings += [String(reflecting: row.primary), String(reflecting: row.summary), String(reflecting: row.reasons),
                String(reflecting: row.relations), String(reflecting: row.metadata), String(reflecting: row.diagnostics)]
        }
        let redacted = strings.allSatisfy { !$0.contains(QueryBatchFixture.common) }
        #expect(redacted)
    }
}
