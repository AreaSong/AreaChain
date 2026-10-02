import Foundation
import Testing
@testable import AreaChain

struct ImageQueryProviderTests {
    @Test func threeOwnersMatchFilenameAndPhraseOrExclusionInInputOrder() {
        for text in ["合成 photo", "\"合成 工作\"", "(不存在 | photo)", "photo -不存在", "(不存在 | \"合成 工作\") -missing"] {
            let response = ImageQueryFixture.read("/images " + text)
            #expect(response.state == .evaluated && response.isCompleteForCoveredTypes)
            #expect(response.matches.map(\.id.id) == ImageQueryFixture.images.map(\.id))
            #expect(response.matches.allSatisfy { $0.id.type == .image })
        }
        for text in ["photo 不存在", "\"工作 合成\"", "photo -工作", "(不存在 | missing)"] {
            let response = ImageQueryFixture.read("/images " + text)
            #expect(response.matches.isEmpty && response.isCompleteForCoveredTypes)
        }
    }

    @Test func ownerTextDoesNotParticipateAndUnicodeRangesAddressOriginalFilename() throws {
        #expect(ImageQueryFixture.read("/images " + ImageAssociationFixture.secret).matches.isEmpty)
        let response = ImageQueryFixture.read("/images (不存在 | café)")
        #expect(response.matches.count == 3)
        for match in response.matches {
            let evidence = try #require(match.evidence.first { $0.field == .filename })
            let range = try #require(evidence.range)
            #expect((match.filename as NSString).substring(with: range) == "Cafe\u{301}")
            #expect(evidence.alternativeIndex == 1 && evidence.ownerObject == nil)
        }
    }

    @Test func ownCreatedAndOwnerDateAreIndependent() {
        let created = DayKey.from(ImageAssociationFixture.date, calendar: ImageQueryFixture.dates.calendar)
        let request = ImageQueryFixture.scheduled("/images date:today created:" + created)
        let response = ImageQueryProvider.read(request)
        #expect(response.matches.count == 3)
        #expect(response.matches.first?.businessDay == "2026-10-01")
        #expect(response.matches[1].businessDay == nil && response.matches[1].dateExistence?.witnessDay == "2026-10-01")
        #expect(response.matches[1].occurrence == nil)
        #expect(response.matches.allSatisfy { $0.evidence.contains { $0.field == .createdAt && $0.ownerObject == nil } })
        #expect(ImageQueryFixture.read("/images created:today").matches.isEmpty)
    }

    @Test func tagsUseOwnerAssociationAndMissingNamesStayUnknown() {
        for source in ["#工作", "(#不存在 | #工作)", "#工作 -#学习"] {
            let response = ImageQueryFixture.read("/images " + source)
            #expect(response.matches.count == 3)
            #expect(response.matches.allSatisfy { $0.evidence.contains {
                $0.field == .ownerTags && $0.ownerObject?.id == ImageQueryFixture.ownerID
                    && $0.relatedObject == .init(type: .tag, id: TodoQueryFixture.work)
            } })
        }
        #expect(ImageQueryFixture.read("/images #工作 #学习").matches.isEmpty)
        #expect(ImageQueryFixture.read("/images -#工作").matches.isEmpty)
        var request = ImageQueryFixture.request("/images -#不存在")
        request.tagNames = nil
        let unknown = ImageQueryProvider.read(request)
        #expect(unknown.matches.isEmpty && unknown.undeterminedObjects.count == 3 && !unknown.isCompleteForCoveredTypes)
        request.tagNames = [:]
        #expect(ImageQueryProvider.read(request).diagnostics.contains { $0.issue == .missingAssociatedTagNames })
    }

    @Test func stableTagsNoTagsAndTaskOrSubtaskDoNotInheritChildren() {
        var owners = ImageQueryFixture.owners
        owners.todos?[0].tagIDs = ""
        let parent = owners.todos![0]
        owners.todos?[0].subtasks = [TodoQueryFixture.subtask(1, parent: parent, tags: [TodoQueryFixture.work])]
        let association = ImageQueryFixture.association(owners: owners)
        var request = ImageQueryFixture.request(association: association)
        request = .init(requestID: request.requestID,
            session: TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)), to: request.session),
            association: association, tagNames: nil)
        #expect(ImageQueryProvider.read(request).matches.map(\.owner.kind) == [.routine, .diary])
        let noTags = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session("/images"))
        let response = ImageQueryProvider.read(.init(requestID: request.requestID, session: noTags, association: association))
        #expect(response.matches.map(\.owner.kind) == [.todo])
        #expect(response.matches[0].evidence.contains { $0.field == .ownerTags && $0.kind == .absence && $0.ownerObject?.type == .todo })
    }

    @Test func taskAttributesRemainOwnedAndDiaryFieldsAreInapplicable() {
        for source in ["!p2", "@09:00", "!p2 @09:00"] {
            let response = ImageQueryFixture.read("/images " + source)
            #expect(response.matches.map(\.owner.kind) == [.todo, .routine])
            #expect(response.diagnostics.contains { $0.issue == .ownerConditionNotApplicable && $0.owner?.kind == .diary })
            #expect(response.matches.allSatisfy { $0.evidence.contains {
                [.ownerPriority, .ownerReminder].contains($0.field) && $0.ownerObject != nil
            } })
        }
        let response = ImageQueryFixture.read("/images status:open")
        #expect(response.matches.map(\.owner.kind) == [.todo])
        #expect(response.undeterminedObjects == [.init(type: .image, id: ImageQueryFixture.images[1].id)])
        #expect(response.diagnostics.contains { $0.issue == .missingOccurrenceDay })
    }

    @Test func knownTagMatchCanDecideDespiteAnUnrelatedMissingName() {
        var owners = ImageQueryFixture.owners
        owners.todos?[0].tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        let association = ImageQueryFixture.association(owners: owners)
        for source in ["#工作", "-#工作"] {
            var request = ImageQueryFixture.request("/images " + source, association: association)
            request.tagNames = [TodoQueryFixture.work: "工作"]
            let response = ImageQueryProvider.read(request)
            #expect(response.undeterminedObjects.isEmpty)
            #expect(response.matches.count == (source == "#工作" ? 3 : 0))
        }
    }

    @Test func todoDoneUsesOwnerFieldAndDoesNotTurnSkippedIntoOpen() {
        var owners = ImageQueryFixture.owners
        owners.todos?[0].isDone = true
        let association = ImageQueryFixture.association(owners: owners)
        let done = ImageQueryFixture.read("/images status:done", association: association)
        #expect(done.matches.map(\.owner.kind) == [.todo])
        #expect(done.matches[0].evidence.contains { $0.field == .ownerCompletion && $0.ownerObject?.type == .todo })
        let skipped = ImageQueryFixture.read("/images on:today status:skipped", association: association)
        #expect(!skipped.matches.contains { $0.owner.kind == .todo })
    }
}
