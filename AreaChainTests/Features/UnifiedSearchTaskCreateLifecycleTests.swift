import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskCreateLifecycleTests {
    @Test(arguments: [false, true]) func lossOfDisplayBeforeOrAfterSaveNeverReplays(afterSave: Bool) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let revoke = { [fixture] in
            try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership)
        }
        if afterSave { fixture.io.afterRegistration = revoke }
        else { fixture.io.beforeTransaction = revoke }
        let source = fixture.controller.buffer
        fixture.submit()
        #expect(try fixture.facts.state == (afterSave ? .saved : .notSubmitted))
        #expect(try fixture.io.capture.readTodos().count == (afterSave ? 1 : 0))
        #expect(fixture.count("save") == (afterSave ? 1 : 0))
        #expect(!fixture.controller.operationVisible)
        fixture.controller.requestOperationSubmit(source)
        fixture.io.beforeTransaction = nil
        fixture.io.afterRegistration = nil
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        _ = try await fixture.results.publish()
        fixture.submit()
        #expect(fixture.count("save") == (afterSave ? 1 : 0))
        #expect(fixture.controller.settingExecution != nil)
    }

    @Test(arguments: [0, 1, 2, 3]) func savedPublicationAndExternalFailureRetainRun(kind: Int) throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        fixture.io.notificationResult = kind == 2 ? .failed : .succeeded
        fixture.io.calendarResult = kind == 3 ? .failed : .succeeded
        if kind == 0 { fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 1 { fixture.environment.afterPublication = { throw TaskCreateCommandIO.Failure.injected } }
        fixture.submit()
        let facts = try fixture.facts
        fixture.controller.acknowledgeTaskCreate(fixture.controller.buffer)
        fixture.submit()
        #expect(facts.state == .saved && facts.savedID != nil)
        #expect(fixture.controller.settingExecution != nil)
        #expect(try fixture.io.capture.readTodos().count == 1 && fixture.count("save") == 1)
        #expect(fixture.count("ui") == (kind == 0 ? 0 : 1))
    }

    @Test func changedSourceFailsWithoutReplacingPreparation() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let queued = try #require(fixture.controller.operations?.active)
        try #require(fixture.controller.enqueue(queued.stamp, source: fixture.controller.buffer))
        fixture.controller.requestTaskCreate(fixture.controller.buffer, prepareOnly: true)
        let prepared = fixture.controller.taskCreatePreparation
        fixture.io.capture.source = "qa.changed"
        fixture.submit()
        #expect(fixture.controller.taskCreateFailure == .stale)
        #expect(fixture.controller.taskCreatePreparation == prepared)
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.count("save") == 0)
    }

    @Test func preparationCallbackCannotBypassDisplayGate() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        fixture.io.sourceRead = { [fixture] in
            try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership)
        }
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil)
        #expect(fixture.controller.plan?.items.count == 1)
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.count("save") == 0)
    }

    @Test func preSaveFailureKeepsOriginalContentWithoutRetry() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        fixture.io.repositoryFactory = { TaskCreateFailureRepository($0) }
        try fixture.start()
        let draft = fixture.controller.operations?.active
        fixture.submit()
        #expect(try fixture.facts.state == .notSubmitted && fixture.facts.rollback == .returned)
        #expect(fixture.controller.settingExecution?.snapshot.items.first?.draft.id == draft?.id)
        fixture.submit()
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.count("save") == 0)
        #expect(fixture.controller.operations?.active == nil)
    }
}
