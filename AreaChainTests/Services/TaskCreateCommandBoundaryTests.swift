import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCommandBoundaryTests {
    @Test(arguments: ["title //", "title // note", "title ／／", "title\nbody", "title #tag",
                      "title @18:00", "title 下午3点", "title !p4", "#1", " ", "title\u{2028}body"])
    func derivedFieldsAndNonTitlesAreRejected(title: String) throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue(TaskCreateCommandFixture.arguments(title))
        #expect(throws: TaskCreateCommandIssue.self) { try fixture.submit() }
        #expect(try fixture.io.capture.readTodos().isEmpty)
        #expect(fixture.io.capture.trace.isEmpty && fixture.io.capture.failures == 0)
    }

    @Test func extraDuplicateWrongTypesAndAllNotesFormsAreRejected() throws {
        let normal = TaskCreateCommandFixture.arguments()
        let invalid: [[CommandArgument]] = [
            normal + [.init(parameter: .notes, operation: .replace, value: .longText(""))],
            normal + [.init(parameter: .notes, operation: .clear)],
            normal + [.init(parameter: .notes, operation: .unspecified)],
            normal + [.init(parameter: .notes, operation: .append, value: .longText("body"))],
            normal + [.init(parameter: .tags, operation: .clear)],
            normal + [.init(parameter: .time, operation: .cancelReminder)],
            normal + [.init(parameter: .priority, operation: .clear)],
            normal + [normal[0]],
            [.init(parameter: .title, operation: .assign, value: .longText("title")), normal[1]],
            [.init(parameter: .title, operation: .clear), normal[1]],
            [normal[0], .init(parameter: .day, operation: .assign, value: .shortText("2026-10-05"))],
            TaskCreateCommandFixture.arguments(day: "2026-02-30"),
            TaskCreateCommandFixture.arguments(day: "today"),
            TaskCreateCommandFixture.arguments(day: "2026-1-01")
        ]
        for arguments in invalid {
            let fixture = try TaskCreateCommandFixture()
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                     arguments: arguments)
            #expect(throws: TaskCreateCommandIssue.self) { try CommandTaskCreateInput(draft) }
            if Set(arguments.map(\.parameter)).count != arguments.count {
                // 原 reducer 已拒绝重复参数，不伪造一个绕过它的活动草稿来测试适配。
                try fixture.handoff.start(draft)
                #expect(try fixture.handoff.state().operations.active == nil)
            } else {
                try fixture.handoff.queue(draft)
                #expect(throws: TaskCreateCommandIssue.self) { try fixture.submit() }
            }
            #expect(try fixture.io.capture.readTodos().isEmpty)
            #expect(fixture.io.capture.trace.isEmpty)
        }
    }

    @Test func protectedUnknownBaselineAndTargetCannotBypassRunGuards() throws {
        let normal = TaskCreateCommandFixture.arguments()
        for protection in [CommandProtectionRequirement.required, .unknown] {
            let draft = CommandDraft(id: UUID(), hostID: "qa", commandID: .init(rawValue: "todo.create"),
                                     arguments: normal, protectionRequirement: protection)
            #expect(throws: TaskCreateCommandIssue.protectedContent) { try CommandTaskCreateInput(draft) }
            #expect(draft.blocksUnprotectedExport)
        }
        let baseline = CommandDraftBaseline([.init(subject: .ambient, parameter: .notes): .uniform(.longText(""))])
        let draft = CommandDraft(id: UUID(), hostID: "qa", commandID: .init(rawValue: "todo.create"),
                                 baseline: baseline, arguments: normal)
        #expect(throws: TaskCreateCommandIssue.protectedContent) { try CommandTaskCreateInput(draft) }
        let target = CommandDraftTargets(.single, objects: [.init(type: .todo, id: UUID())])
        let targeted = CommandDraft(id: UUID(), hostID: "qa", commandID: .init(rawValue: "todo.create"),
                                    targets: target, arguments: normal)
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try CommandTaskCreateInput(targeted) }
    }

    @Test func dirtyContextIsPreservedBeforePrepareAndExecute() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        _ = try fixture.prepare()
        let request = try fixture.request()
        let pending = TodoItem(title: "pending", dayKey: "2026-10-04")
        fixture.io.capture.context.insert(pending)
        #expect(throws: TaskCreateCommandIssue.dirtyContext) { try fixture.adapter.execute(request) }
        #expect(fixture.io.capture.context.hasChanges && pending.title == "pending")
        #expect(try fixture.io.capture.readTodos().isEmpty)
        #expect(fixture.io.capture.trace.isEmpty)
        let other = try TaskCreateCommandFixture()
        try other.queue()
        other.io.capture.context.insert(TodoItem(title: "pending", dayKey: "2026-10-04"))
        #expect(throws: TaskCreateCommandIssue.dirtyContext) { try other.prepare() }
        #expect(other.io.capture.context.hasChanges && other.io.capture.trace.isEmpty)
    }

    @Test func lastInjectedCallbackCannotPresavePendingChanges() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        fixture.io.beforeTransaction = {
            fixture.io.capture.context.insert(TodoItem(title: "pending", dayKey: "2026-10-04"))
        }
        let facts = try fixture.submit()
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .notCalled)
        #expect(fixture.io.capture.context.hasChanges)
        #expect(try fixture.io.capture.context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try fixture.io.capture.readTodos().isEmpty)
        #expect(fixture.count("save") == 0 && fixture.count("preSave") == 0 && fixture.count("ui") == 0)
    }

    @Test func sourceAndVersionsAreFrozenAcrossRepeatedPreview() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        let prepared = try fixture.prepare()
        fixture.io.capture.source = "qa.changed"
        #expect(throws: TaskCreateCommandIssue.stale) { try fixture.prepare() }
        fixture.io.capture.source = prepared.source.bundleID
        #expect(try fixture.prepare().creationID == prepared.creationID)
        try fixture.handoff.send(.query(.setInput("changed query")))
        #expect(throws: TaskCreateCommandIssue.stale) { try fixture.prepare() }
        #expect(fixture.io.capture.trace.isEmpty)
    }

    @Test func sourceChangedDuringExecutionRejectsOriginalAttempt() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        _ = try fixture.prepare()
        let request = try fixture.request()
        fixture.io.capture.source = "qa.new"
        #expect(throws: TaskCreateCommandIssue.sourceChanged) { try fixture.adapter.execute(request) }
        #expect(try fixture.unit().local == .notSubmitted && fixture.unit().state == .failed)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func multipleItemsLinksAndNestedTransactionDoNotCreate() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        try fixture.queue()
        #expect(throws: TaskCreateCommandIssue.unsupportedPlan) { try fixture.submit() }
        #expect(fixture.count("save") == 0)
        let single = try TaskCreateCommandFixture()
        try single.queue()
        _ = try single.prepare()
        let request = try single.request()
        try ModelChanges.transaction(in: single.io.capture.context, boundary: single.io.capture.boundary) {
            #expect(throws: TaskCreateCommandIssue.nestedTransaction) { try single.adapter.execute(request) }
            #expect(single.count("save") == 0)
        }
        #expect(try single.io.capture.readTodos().isEmpty)
        var item = try #require(fixture.handoff.state().plan.items.first)
        item.links.predecessors = [UUID()]
        #expect(throws: TaskCreateCommandIssue.unsupportedPlan) { try CommandHandoffCoordinator.validateTaskCreateItem(item) }
        item.links = .init()
        item.atomicGroup = UUID()
        #expect(throws: TaskCreateCommandIssue.unsupportedPlan) { try CommandHandoffCoordinator.validateTaskCreateItem(item) }
    }

    @Test(arguments: [false, true])
    func sourceAndRepositoryCallbacksCannotHideDirtyContext(fromRepository: Bool) throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        _ = try fixture.prepare()
        let request = try fixture.request()
        let dirty = {
            fixture.io.capture.context.insert(TodoItem(title: "pending", dayKey: "2026-10-04"))
        }
        if fromRepository {
            fixture.io.repositoryFactory = { context in dirty(); return SwiftDataTaskRepository(context: context) }
            let facts = try fixture.adapter.execute(request)
            #expect(facts.state == .notSubmitted && facts.rollback == .notCalled)
        } else {
            fixture.io.sourceRead = dirty
            #expect(throws: TaskCreateCommandIssue.dirtyContext) { try fixture.adapter.execute(request) }
        }
        #expect(fixture.io.capture.context.hasChanges)
        #expect(try fixture.io.capture.readTodos().isEmpty)
        #expect(fixture.count("save") == 0 && fixture.count("preSave") == 0)
    }

    @Test func ordinarySourceMustBeExplicitAndPlanEditsInvalidatePreparation() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        for protection in [CommandProtectionRequirement.required, .unknown] {
            fixture.io.protection = protection
            #expect(throws: TaskCreateCommandIssue.protectedContent) { try fixture.prepare() }
        }
        fixture.io.protection = .ordinary
        let prepared = try fixture.prepare()
        try fixture.handoff.plan(.beginEditing(prepared.item))
        try fixture.handoff.plan(.edit(prepared.item, .init(parameter: .title, operation: .assign, value: .shortText("changed"))))
        let current = try #require(fixture.handoff.state().plan.items.first)
        try fixture.handoff.plan(.endEditing(current.stamp, .finish))
        #expect(throws: TaskCreateCommandIssue.stale) { try fixture.prepare() }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func sourceFailuresAndDescriptionsDoNotExposeContent() throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        let prepared = try fixture.prepare()
        for description in [String(describing: prepared), String(reflecting: prepared.input), String(describing: prepared.source)] {
            #expect(!description.contains("合成普通任务") && !description.contains(fixture.io.capture.source))
        }
        fixture.io.sourceRead = { throw NSError(domain: "synthetic-source-content", code: 1) }
        #expect(throws: TaskCreateCommandIssue.sourceUnavailable) { try fixture.prepare() }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }
}
