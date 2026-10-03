import Foundation
import Testing
@testable import AreaChain

struct ContentQueryBatchProtectionTests {
    @Test func knownNonmatchCanResolveProtectedAssociationWithoutDroppingItsDiagnostic() {
        var batch = QueryBatchFixture.mixed("absent-term has:image")
        batch = QueryBatchFixture.replacingSession(batch,
            TodoQueryFixture.add(.page(.contentTypes([.todo])), to: batch.session))
        var image = batch.snapshots.images.values![0]
        image.protection = .protected
        batch.snapshots.images = .complete([image])
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.canDeclareCompleteNoMatch)
        #expect(result.completeness.providers[0].hints.contains(.nonPublicCoverage))
        guard case .todo(let reading) = result.readings.first else { Issue.record("缺少任务读取"); return }
        #expect(reading.diagnostics.contains { $0.issue == .imageAssociation(.protectedAssociation) && !$0.affectsDetermination })
    }

    @Test func partialPrimarySourceCannotBorrowWholeTypeImageCompleteness() {
        var batch = QueryBatchFixture.mixed("/images")
        batch.snapshots.todos = .partial(batch.snapshots.todos.values!)
        let ownersPartial = ContentQueryBatchReader.read(batch)
        #expect(ownersPartial.matches.isEmpty && !ownersPartial.canDeclareCompleteNoMatch)
        batch.snapshots.todos = .complete(batch.snapshots.todos.values!)
        batch.snapshots.images = .partial(batch.snapshots.images.values!)
        let imagesPartial = ContentQueryBatchReader.read(batch)
        #expect(imagesPartial.matches.isEmpty && !imagesPartial.canDeclareCompleteNoMatch)
        let hasImage = ContentQueryBatchReader.read(QueryBatchFixture.replacingSession(batch,
            TodoQueryFixture.add(.page(.contentTypes([.todo])), to: TodoQueryFixture.session("has:image"))))
        #expect(hasImage.matches.isEmpty && !hasImage.canDeclareCompleteNoMatch)
    }

    @Test func imageAndHasImageUseSameOwnersEvenWhenRequestIDIsReused() {
        var batch = QueryBatchFixture.mixed("has:image")
        let present = ContentQueryBatchReader.read(batch)
        #expect(present.matches.map(\.id.type) == [.todo])
        let imageBatch = QueryBatchFixture.replacingSession(batch, TodoQueryFixture.session("/images"))
        #expect(ContentQueryBatchReader.read(imageBatch).definiteMatchCount == 1)
        var todo = batch.snapshots.todos.values![0]
        todo.deletedAt = TodoQueryFixture.created
        batch.snapshots.todos = .complete([todo])
        #expect(ContentQueryBatchReader.read(batch).matches.isEmpty)
        let removed = QueryBatchFixture.replacingSession(batch, TodoQueryFixture.session("/images"))
        #expect(ContentQueryBatchReader.read(removed).matches.isEmpty)
        #expect(removed.requestID == imageBatch.requestID)
    }

    @Test func hiddenDiaryAndProtectedImageOutputsDoNotRevealRawValuesOrCounts() {
        var batch = QueryBatchFixture.empty()
        var diary = ImageAssociationFixture.diary(QueryBatchFixture.id)
        diary.isPrivate = true
        batch.snapshots.diaries = .complete([diary])
        var observations: [Set<String>] = []
        for count in [0, 1, 3] {
            batch.snapshots.images = .complete((0..<count).map { _ in
                var image = ImageAssociationFixture.image(owner: .init(kind: .diary, id: diary.id))
                image.filename = ImageAssociationFixture.secret
                return image
            })
            let result = ContentQueryBatchReader.read(batch)
            #expect(!ImageAssociationFixture.containsSecret(result))
            #expect(result.definiteMatchCount == 1 && !result.completeness.matchingIsComplete)
            #expect(result.matches.allSatisfy { $0.id.type == .diary })
            observations.append(TrashQueryFixture.strings(result))
            guard case .diary(let match) = result.matches.first else { Issue.record("缺少手记投影"); return }
            guard case .hiddenTitle = match.presentation else { Issue.record("隐藏分支被展开"); return }
        }
        #expect(observations.dropFirst().allSatisfy { $0 == observations.first })
    }

    @Test func sameMetadataProtectsDiaryAndItsImageAssociation() {
        var batch = QueryBatchFixture.empty("has:image")
        var diary = ImageAssociationFixture.diary(QueryBatchFixture.id)
        diary.tagIDs = TagIDList.encode([TodoQueryFixture.work])
        batch.snapshots.diaries = .complete([diary])
        batch.snapshots.images = .complete([ImageAssociationFixture.image(owner: .init(kind: .diary, id: diary.id))])
        batch.facts.metadata = .init(tagNames: [TodoQueryFixture.work: "工作"], privateTagIDs: [])
        #expect(ContentQueryBatchReader.read(batch).matches.map(\.id.type) == [.diary])
        batch.facts.metadata = .init(tagNames: [TodoQueryFixture.work: "工作"], privateTagIDs: [TodoQueryFixture.work])
        let protected = ContentQueryBatchReader.read(batch)
        #expect(protected.matches.isEmpty && !protected.canDeclareCompleteNoMatch)
        let images = ContentQueryBatchReader.read(QueryBatchFixture.replacingSession(batch, TodoQueryFixture.session("/images")))
        #expect(images.matches.isEmpty && !images.canDeclareCompleteNoMatch)
    }

    @Test func trashChildHitIsPromotedWithoutCountingContextAsHit() {
        let result = ContentQueryBatchReader.read(QueryBatchFixture.trash("/trash 合成子任务"))
        #expect(result.readings.map(\.provider) == [.trash])
        #expect(result.definiteMatchCount == 1 && result.visibleGroupCount == 1 && result.visibleContextCount == 2)
        guard case .trash(let reading) = result.readings.first else { Issue.record("缺少墓碑读取"); return }
        let child = TrashFixture.ref(.subtask, TrashFixture.childID)
        #expect(reading.groups.first?.displayAnchor == child)
        #expect(reading.groups.first?.matches == [child])
        #expect(reading.matches.first?.object.restoration.independent == .notProvided)
        #expect(reading.matches.first?.object.restoration.mayRestoreWithParent == TrashFixture.ref(.todo))
        #expect(reading.groups.first?.context.allSatisfy { $0.id != child } == true)
        #expect(!result.completeness.matchingIsComplete)
    }

    @Test func trashCanKeepOrphanSubtaskButNeverMixesLiveMatches() {
        var batch = QueryBatchFixture.trash()
        batch.snapshots.todos = .complete([TrashFixture.todo(deleted: nil)])
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.readings.map(\.provider) == [.trash])
        #expect(!result.matches.contains { $0.id.type == .todo })
        #expect(result.matches.contains { $0.id.type == .subtask })
        #expect(!result.consistencyIssues.contains(.uncontainedSubtasks))
    }

    @Test func descriptionsDoNotExpandQueryOrProjection() {
        let batch = QueryBatchFixture.mixed()
        let result = ContentQueryBatchReader.read(batch)
        let descriptions = [String(reflecting: batch), String(reflecting: batch.snapshots),
            String(reflecting: batch.facts), String(reflecting: result)]
            + result.matches.map { String(reflecting: $0) } + result.readings.map { String(reflecting: $0) }
        #expect(descriptions.allSatisfy { !$0.contains(QueryBatchFixture.common) })
    }
}
