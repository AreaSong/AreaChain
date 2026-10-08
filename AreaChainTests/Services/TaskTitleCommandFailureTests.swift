import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitleCommandFailureTests {
    @Test func duplicateAdaptersAndReentrantSourceCannotModifyTwice() throws {
        let fixture = try TaskTitleCommandFixture()
        _ = try fixture.accept(fixture.prepare("新标题 #恢复 #新"))
        let request = try fixture.request()
        let second = TaskTitleCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        var reentries = 0
        fixture.io.sourceRead = {
            reentries += 1
            #expect(throws: TaskTitleCommandIssue.alreadyInvoked) { try second.execute(request) }
        }
        #expect(try fixture.adapter.execute(request).state == .saved)
        #expect(reentries >= 1)
        #expect(throws: (any Error).self) { try second.execute(request) }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(try fixture.base.fields().tags == ["Work", "恢复", "新"])
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TagItem>()) == 3)
    }

    @Test func preparationReentrancyCannotReplaceAcceptedEvidence() throws {
        let fixture = try TaskTitleCommandFixture()
        var attempts = 0
        fixture.io.sourceRead = {
            attempts += 1
            #expect(throws: CommandExecutionError.busy) {
                try fixture.adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
            }
        }
        let accepted = try fixture.accept(fixture.prepare("新 #新"))
        #expect(attempts == 2 && accepted.tagCreationIDs.count == 1)
        #expect(fixture.base.io.trace.isEmpty)
    }

    @Test(arguments: [false, true])
    func commonRollbackAndSaveThenThrowPreserveUnknown(savedFirst: Bool) throws {
        let fixture = try TaskTitleCommandFixture()
        let before = try fixture.base.fields()
        let accepted = try fixture.accept(fixture.prepare("新标题 #恢复 #新 !p3 @18:00"))
        fixture.io.saveMode = savedFirst ? .throwAfter : .throwBefore
        let request = try fixture.request()
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .unknown && facts.save == .called && facts.rollback == .returned)
        #expect(try fixture.unit().state == .verificationRequired && fixture.unit().local == .unknown)
        #expect(try fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 0 && fixture.base.io.authorizations.isEmpty)
        if savedFirst {
            let todo = try #require(fixture.base.io.readTodos().first)
            #expect(todo.title == "新标题" && todo.isUrgent && !todo.isImportant && todo.remindMinutes == 1080)
            #expect(try fixture.base.fields().tags == ["Work", "恢复", "新"])
            #expect(fixture.base.deleted.deletedAt == nil)
        } else {
            #expect(try fixture.base.fields() == before)
            #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TagItem>()) == 2)
        }
        let verification = try fixture.adapter.verifyUnknown(request.operation, expecting: fixture.handoff.owned().lease)
        #expect(verification.presence == .live && verification.originalFacts == facts)
        #expect(verification.currentValues[.title] == .text(savedFirst ? "新标题" : "原标题"))
        #expect(verification.operation == request.operation && verification.attempt == request.attempt)
        #expect(try fixture.unit().taskTitle == facts)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1)
    }

    @Test(arguments: ["registration", "publicationBefore", "publicationAfter", "external"])
    func localFactPrecedesPublicationAndFailuresNeverRepeatWrites(kind: String) throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare("新标题 #恢复 @18:00"))
        fixture.io.afterRegistration = {
            #expect(try fixture.unit().taskTitle?.state == .saved && fixture.unit().local == .committed)
            #expect(fixture.count("ui") == 0)
            if kind == "registration" { throw TaskCreateCommandIO.Failure.injected }
        }
        fixture.environment.beforePublication = {
            #expect(try fixture.unit().taskTitle?.state == .saved)
            if kind == "publicationBefore" { throw TaskCreateCommandIO.Failure.injected }
        }
        fixture.environment.afterPublication = {
            if kind == "publicationAfter" { throw TaskCreateCommandIO.Failure.injected }
        }
        if kind == "external" { fixture.io.onRefresh = { throw TaskCreateCommandIO.Failure.injected } }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .saved && facts.save == .returned)
        #expect(facts.registrationFailed == (kind == "registration"))
        #expect(facts.publicationFailed == (kind == "publicationBefore" || kind == "publicationAfter"))
        #expect(facts.refreshRequested == (kind != "publicationBefore"))
        #expect(fixture.base.todo.title == "新标题" && fixture.base.deleted.deletedAt == nil)
        #expect(fixture.count("save") == 1 && fixture.base.io.authorizations == [1080])
        #expect(try fixture.unit().local == .committed)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1)
    }

    @Test(arguments: [false, true])
    func revocationBeforeCommitRejectsButAfterCommitKeepsOriginalRun(afterCommit: Bool) throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare())
        let ownership = try fixture.handoff.owned().lease.ownership
        if afterCommit {
            fixture.environment.beforePublication = {
                _ = try fixture.handoff.coordinator.invalidateSearch(ownedBy: ownership)
            }
        } else {
            fixture.io.beforeTransaction = {
                _ = try fixture.handoff.coordinator.invalidateSearch(ownedBy: ownership)
            }
        }
        if afterCommit {
            #expect(try fixture.submit(accepted).state == .saved)
            #expect(try fixture.unit().taskTitle?.state == .saved && fixture.unit().local == .committed)
            #expect(fixture.count("save") == 1)
        } else {
            #expect(throws: (any Error).self) { try fixture.submit(accepted) }
            #expect(try fixture.unit().local == .notSubmitted)
            #expect(fixture.count("save") == 0 && fixture.base.todo.title == "原标题")
        }
    }

    @Test func sourceAndNotesChangesAtFinalBoundaryReject() throws {
        for kind in ["revision", "notes", "dirty"] {
            let fixture = try TaskTitleCommandFixture()
            let accepted = try fixture.accept(fixture.prepare())
            fixture.io.beforeTransaction = {
                if kind == "revision" { fixture.io.revision = UUID() }
                if kind == "notes" { fixture.io.notes = .present }
                if kind == "dirty" { fixture.base.todo.dueMinutes = 1200 }
            }
            #expect(throws: TaskTitleCommandIssue.self) { try fixture.submit(accepted) }
            #expect(fixture.base.todo.title == "原标题" && fixture.count("save") == 0 && fixture.count("ui") == 0)
            if kind == "dirty" { #expect(fixture.base.io.context.hasChanges && fixture.base.todo.dueMinutes == 1200) }
        }
    }

    @Test func finalServiceValidationFailureKeepsNoCommitAndOriginalAcceptance() throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare())
        var validations = 0
        fixture.io.beforeTransaction = {
            validations += 1
            if validations == 2 {
                fixture.base.todo.title = "最后改变"
                try fixture.base.io.context.save()
            }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.conflict == .fieldsChanged([.title]))
        #expect(try fixture.unit().state == .conflict && fixture.unit().taskTitle == facts)
        #expect(fixture.base.todo.title == "最后改变" && fixture.count("save") == 0)
        #expect(try fixture.handoff.coordinator.taskTitles.acceptances[accepted.preview.binding.draft.draftID] == accepted)
    }
}
