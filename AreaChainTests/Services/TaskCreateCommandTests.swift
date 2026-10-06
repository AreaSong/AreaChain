import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCommandTests {
    @Test func actualCreateFreezesIdentityAndKeepsRequestedEffectsUnverified() throws {
        let fixture = try TaskCreateCommandFixture()
        let item = try fixture.queue()
        let prepared = try fixture.prepare()
        #expect(try fixture.io.capture.readTodos().isEmpty)
        #expect(fixture.io.capture.trace.isEmpty)
        #expect(try fixture.prepare() == prepared)
        let facts = try fixture.submit()
        let saved = try #require(fixture.io.capture.readTodos().first)
        #expect(facts.savedID == prepared.creationID && facts.state == .saved)
        #expect(saved.id == prepared.creationID && saved.title == "合成普通任务" && saved.dayKey == "2026-10-05")
        #expect(saved.sourceBundleID == fixture.io.capture.source && saved.remindMinutes == nil)
        #expect(saved.notes.isEmpty && saved.tagIDs.isEmpty && !saved.isImportant && !saved.isUrgent)
        #expect(try fixture.io.capture.readTodos().count == 1)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.count("reminderRefresh") == 1 && fixture.count("calendarRefresh") == 1)
        #expect(fixture.io.capture.authorizations.isEmpty)
        #expect(fixture.environment.observedRefresh?.calendarRequested == true)
        #expect(facts.refreshRequested && facts.notificationRequested == true && facts.calendarRequested == true)
        #expect(try fixture.unit().taskCreation == facts)
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .verificationRequired)
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.outputs[item] == .init(type: .todo, id: saved.id))
        #expect(run.creationOutput(for: .init(producer: prepared.item, outputType: .todo)) == nil)
    }

    @Test func originalArgumentsThroughDraftPlanAdapterDatabaseAndOutputReference() throws {
        let fixture = try TaskCreateCommandFixture()
        let parsed = CommandPathParser().parse(.init(text: "/tasks/add", locale: Locale(identifier: "en")))
        let command = try #require(parsed.command)
        #expect(command.id.rawValue == "todo.create")
        let raw = TaskCreateCommandFixture.arguments("  ordinary   title  ")
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: command.id, arguments: raw)
        let item = try fixture.handoff.queue(draft)
        let prepared = try fixture.prepare()
        #expect(prepared.input?.arguments == raw && prepared.input?.parsed.cleanTitle == "ordinary title")
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        let facts = try fixture.submit()
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.snapshot.items[0].draft.id == draft.id && run.snapshot.items[0].draft.arguments == raw)
        let reference = CommandCreationReference(producer: prepared.item, outputType: .todo)
        #expect(run.creationOutput(for: reference) == .init(type: .todo, id: facts.creationID))
        #expect(try run.outputs[item]?.id == fixture.io.capture.readTodos().first?.id)
        #expect(fixture.io.notificationProcessed == 1 && fixture.io.calendarProcessed == 1)
        #expect(run.units.count == 1 && run.units[0].attempt == 2 && run.units[0].state == .succeeded)
        #expect(!run.isExecutable && command.execution == .unwired)
        #expect(!fixture.adapter.supports(.init(rawValue: "todo.title")))
    }

    @Test(arguments: ["  plain   title ", "https://example.invalid/a", "literal \\#tag", "中文普通标题"])
    func originalUIAndAdapterFieldsAndSourcesAgree(title: String) throws {
        let fixture = try TaskCreateCommandFixture()
        let legacy = try TaskCaptureFixture()
        _ = try fixture.queue(TaskCreateCommandFixture.arguments(title))
        _ = try fixture.submit()
        #expect(DayBoardMutations.addCapturedTodo(text: title, dayKey: "2026-10-05", context: legacy.context,
                                                dependencies: legacy.dependencies))
        #expect(try fixture.io.capture.fields() == legacy.fields())
        #expect(fixture.io.capture.trace == legacy.trace)
        #expect(try fixture.io.capture.readTodos()[0].id != legacy.readTodos()[0].id)
    }

    @Test func unassembledAndProductionLikeEnvironmentCannotExecute() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        let closed = TaskCreateCommandAdapter(coordinator: fixture.handoff.coordinator)
        #expect(!closed.supports(.init(rawValue: "todo.create")))
        #expect(throws: TaskCreateCommandIssue.unassembled) {
            try closed.submit(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        fixture.io.capture.context.autosaveEnabled = true
        #expect(throws: TaskCreateCommandIssue.ineligibleEnvironment) { try fixture.prepare() }
        #expect(try fixture.io.capture.trace.isEmpty && fixture.handoff.state().execution == nil)
    }

    @Test func savedOutputRegisteredBeforePrivateEventInvalidatesSearch() throws {
        let fixture = try TaskCreateCommandFixture()
        let item = try fixture.queue()
        let prepared = try fixture.prepare()
        let originalLease = try fixture.handoff.owned().lease
        let observer = fixture.io.capture.center.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated {
                let run = try? fixture.handoff.state().execution
                #expect(run?.outputs[item]?.id == prepared.creationID)
                #expect(run?.units.first?.local == .committed)
                _ = try? fixture.handoff.coordinator.invalidateSearch(ownedBy: originalLease.ownership)
            }
        }
        defer { fixture.io.capture.center.removeObserver(observer) }
        let facts = try fixture.submit()
        #expect(facts.savedID == prepared.creationID)
        #expect(try fixture.unit().taskCreation?.savedID == prepared.creationID)
        #expect(throws: CommandHandoffError.stale) { try fixture.handoff.coordinator.validate(originalLease) }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }
}
