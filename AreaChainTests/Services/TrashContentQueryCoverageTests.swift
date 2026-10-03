import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TrashContentQueryCoverageTests {
    enum Failure: Error { case syntheticDatabaseMessageMustNotEscape }

    @Test(arguments: [0, 1, 2, 3, 4, 5]) func eachFetchFailureRemainsFailedWithoutExposingError(index: Int) throws {
        let types: [CommandObjectType] = [.todo, .subtask, .routine, .diary, .tag, .image]
        let f = try SearchReadFixture.trash { reads in
            switch index {
            case 0: reads.todos = { throw Failure.syntheticDatabaseMessageMustNotEscape }
            case 1: reads.subtasks = { throw Failure.syntheticDatabaseMessageMustNotEscape }
            case 2: reads.routines = { throw Failure.syntheticDatabaseMessageMustNotEscape }
            case 3: reads.diaries = { throw Failure.syntheticDatabaseMessageMustNotEscape }
            case 4: reads.tags = { throw Failure.syntheticDatabaseMessageMustNotEscape }
            default: reads.images = { throw Failure.syntheticDatabaseMessageMustNotEscape }
            }
        }
        let prepared = try f.prepareTrash()
        #expect(prepared.details.sources[types[index]] == .failed)
        #expect(prepared.details.issues.contains(.fetchFailed(types[index])))
        #expect(!String(reflecting: prepared.details).contains("syntheticDatabaseMessageMustNotEscape"))
    }

    @Test func freshPartialReadDoesNotInheritPreviousCompleteCoverage() async throws {
        var partial = false
        let f = try SearchReadFixture.trash { reads in
            let original = reads.images
            reads.images = { partial ? .partial([]) : try original() }
        }
        let task = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created)
        f.image(.init(kind: .todo, id: task.id), deleted: TodoQueryFixture.created)
        let complete = try SearchReadFixture.trashResponse(await f.publishTrash())
        #expect(complete.typeCoverage[.image] == .completeIncludingDeleted)
        partial = true
        let next = try SearchReadFixture.trashResponse(await f.publishTrash())
        #expect(next.typeCoverage[.image] == .partial)
        #expect(!next.matches.contains { $0.id.type == .image })
        #expect(next.groups.first?.source.imageInputRead == .partial)
    }

    @Test(arguments: [0, 1, 2, 3]) func sourceStatesAreDistinct(mode: Int) async throws {
        let f = try SearchReadFixture.trash { reads in
            reads.images = {
                switch mode {
                case 0: .notProvided
                case 1: .partial([])
                case 2: throw Failure.syntheticDatabaseMessageMustNotEscape
                default: .complete([])
                }
            }
        }
        let prepared = try f.prepareTrash()
        try f.session.evaluate(prepared.handle)
        try await f.session.publish(prepared.handle)
        let response = try SearchReadFixture.trashResponse(f.session.presentation())
        let expected: [ContentQuerySourceCoverage] = [.notProvided, .partial, .failed, .complete]
        let coverage: [TrashReadCompleteness] = [.notProvided, .partial, .notProvided, .completeIncludingDeleted]
        #expect(prepared.details.sources[.image] == expected[mode])
        #expect(response.typeCoverage[.image] == coverage[mode])
        #expect(response.matches.isEmpty)
        #expect(!TrashQueryFixture.strings(prepared.details).contains("syntheticDatabaseMessageMustNotEscape"))
        if mode == 2 { #expect(prepared.details.issues.contains(.fetchFailed(.image))) }
    }

    @Test func orphanRowsAndLiveDeletedCollisionsRemainVisibleAsReadingProblems() async throws {
        let f = try SearchReadFixture.trash()
        let date = TodoQueryFixture.created
        let task = f.data.tags.family.task.todo(deleted: date)
        let valid = f.data.tags.family.task.child(task, title: "valid", deleted: date)
        let orphan = f.data.tags.family.task.child(nil, deleted: date)
        let collision = f.data.tags.family.task.child(task, title: "ambiguous", deleted: date)
        f.data.tags.family.task.child(nil).id = collision.id
        let duplicate = f.data.tags.family.task.todo(deleted: date)
        f.data.tags.family.task.todo().id = duplicate.id
        let prepared = try f.prepareTrash()
        #expect(prepared.details.sources[.subtask] == .complete)
        #expect(prepared.details.issues.contains(.unconvertibleSubtask))
        try f.session.evaluate(prepared.handle)
        try await f.session.publish(prepared.handle)
        let result = try SearchReadFixture.trashResponse(f.session.presentation())
        #expect(result.matches.contains { $0.id.id == valid.id })
        #expect(!result.matches.contains { [orphan.id, collision.id, duplicate.id].contains($0.id.id) })
        #expect(result.readingDiagnostics.contains { $0.object?.id == orphan.id && $0.issue == .missingSubtaskParent })
        #expect(result.readingDiagnostics.contains { $0.object?.id == collision.id && $0.issue == .duplicateIdentity })
        #expect(result.readingDiagnostics.contains { $0.object?.id == duplicate.id && $0.issue == .duplicateIdentity })
        #expect(result.typeCoverage[.subtask] == .partial)
        #expect(result.groups.first { $0.source.id.id == task.id }?.source.subtaskRead == .partial)
    }

    @Test func crossTypeUUIDsDoNotConflictOrRepairUnknownOwners() async throws {
        let f = try SearchReadFixture.trash()
        let date = TodoQueryFixture.created
        let task = f.data.tags.family.task.todo(deleted: date)
        let routine = f.data.tags.family.routine(deleted: date); routine.id = task.id
        let diary = f.data.diary("ordinary", deleted: date); diary.id = task.id
        let image = f.image(.init(kind: .routine, id: task.id), deleted: date)
        let unknown = f.image(.init(kind: .todo, id: task.id), deleted: date); unknown.ownerKind = "wrong"
        let result = try SearchReadFixture.trashResponse(await f.publishTrash())
        #expect(result.matches.filter { $0.id.id == task.id }.count == 3)
        #expect(result.matches.first { $0.id.id == image.id }?.object.relation == .cascaded(parent: .init(type: .routine, id: task.id)))
        #expect(!result.matches.contains { $0.id.id == unknown.id })
        #expect(result.readingDiagnostics.contains { $0.issue == .unknownOwnerKind && $0.object == nil })
    }

    @Test func missingParentAndUnreadParentTypeStayDifferent() async throws {
        for unread in [false, true] {
            let f = try SearchReadFixture.trash { reads in if unread { reads.todos = { .notProvided } } }
            let image = f.image(.init(kind: .todo, id: UUID()), deleted: TodoQueryFixture.created)
            let result = try SearchReadFixture.trashResponse(await f.publishTrash())
            #expect(result.readingDiagnostics.contains {
                $0.object?.id == image.id && $0.issue == (unread ? .parentNotProvided : .parentMissing)
            })
        }
    }

    @Test func partialAndInvalidDatesCannotClaimCompleteRelations() async throws {
        var selected: [AttachmentItem] = []
        let f = try SearchReadFixture.trash { reads in reads.images = { .partial(selected) } }
        let task = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created)
        selected = [f.image(.init(kind: .todo, id: task.id), deleted: TodoQueryFixture.created)]
        f.image(.init(kind: .todo, id: task.id), deleted: TodoQueryFixture.created)
        let invalid = f.data.tags.family.task.todo(deleted: Date(timeIntervalSince1970: .infinity))
        let result = try SearchReadFixture.trashResponse(await f.publishTrash())
        #expect(result.typeCoverage[.image] == .partial)
        #expect(!result.matches.contains { $0.id.type == .image || $0.id.id == invalid.id })
        #expect(result.readingDiagnostics.contains { $0.object?.id == invalid.id && $0.issue == .invalidDeletedAt })
        #expect(result.groups.first { $0.source.id.id == task.id }?.source.imageInputRead == .partial)
    }

    @Test func dishonestCompleteAndCrossContextRowsAreRejected() throws {
        var subset: [TodoItem] = []
        let f = try SearchReadFixture.trash { reads in reads.todos = { .complete(subset) } }
        let task = f.data.tags.family.task.todo()
        f.data.tags.family.task.todo(deleted: TodoQueryFixture.created).id = task.id
        subset = [task]
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareTrash() }
        let other = try TaskContentQueryFixture()
        subset = [other.todo()]
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareTrash() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func hasImageAndHistoricalRoutineQueriesKeepCapabilityGaps() async throws {
        let f = try SearchReadFixture.trash()
        let routine = f.data.tags.family.routine(deleted: TodoQueryFixture.created)
        let task = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created)
        f.image(.init(kind: .todo, id: task.id), deleted: TodoQueryFixture.created)
        let images = try SearchReadFixture.trashResponse(await f.publishTrash("/trash has:image"))
        #expect(images.matches.isEmpty && images.diagnostics.contains { $0.issue == .imageAssociationUnavailable })
        let history = try SearchReadFixture.trashResponse(await f.publishTrash("/trash on:2026-09-30 status:open", types: [.routine]))
        #expect(history.matches.isEmpty && history.undeterminedObjects.contains { $0.id == routine.id })
    }
}
