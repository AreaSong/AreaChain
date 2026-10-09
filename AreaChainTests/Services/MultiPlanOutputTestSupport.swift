import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 同一合成库、原事件和事务；各消费适配仍独立证明普通来源。
@MainActor final class MultiPlanOutputFixture {
    let io: TaskChainCommandIO
    let handoff: HandoffFixture
    var context: ModelContext { io.creation.capture.context }
    var subtaskEnvironment: SubtaskCommandEnvironment!
    var adapter: MultiPlanCommandAdapter!
    var subtaskSaveMode = TaskCreateCommandIO.SaveMode.normal
    var subtaskBefore: (() throws -> Void)?
    var subtaskSourceRead: (() throws -> Void)?
    var subtaskSourceRequests: [CommandSubtaskSourceRequest] = []
    var sourceRevision = UUID()
    var childRevision = UUID()

    init(capability: CommandMultiPlanOutputCapability = .typedCreation,
         composition: TaskCreateCommandAdapter.Capability = .minimal) throws {
        io = try TaskChainCommandIO()
        handoff = try HandoffFixture()
        var boundary = io.creation.capture.boundary
        boundary.save = { [unowned self] context in
            io.creation.capture.trace.append("saveSubtask")
            if subtaskSaveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            if subtaskSaveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        subtaskEnvironment = try .init(context: context, center: io.creation.capture.center,
            dependencies: .init(repository: { SwiftDataTaskRepository(context: $0) }, transaction: boundary,
                registerLocalModification: { [unowned self] id in io.creation.capture.registered.append(id) },
                validateBeforeTransaction: { [unowned self] in try subtaskBefore?() }),
            source: { [unowned self] request in
                subtaskSourceRequests.append(request)
                try subtaskSourceRead?()
                return .init(parent: .init(revision: sourceRevision, protection: .ordinary, notes: .absent),
                    subtask: request.target == nil ? nil : .init(revision: childRevision, protection: .ordinary),
                    input: .init(revision: sourceRevision, protection: .ordinary))
            }, refresh: { _, calendar in
                .init(notificationRequested: true, calendarRequested: calendar,
                      notificationResult: .succeeded, calendarResult: .succeeded)
            })
        let coordinator = handoff.coordinator
        adapter = .init(coordinator: coordinator, adapters: .init(
            taskCreate: .init(coordinator: coordinator, environment: io.createEnvironment, capability: composition),
            taskTitle: .init(coordinator: coordinator, environment: io.titleEnvironment),
            taskField: .init(coordinator: coordinator, environment: io.titleEnvironment, capability: .milestone2),
            subtask: .init(coordinator: coordinator, environment: subtaskEnvironment)), outputCapability: capability)
    }

    @discardableResult func queue(_ command: String, _ arguments: [CommandArgument],
                                  from producer: CommandPlanItem? = nil, parameter: CommandParameterID = .target) throws -> CommandPlanItem {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command), arguments: arguments))
        var item = try #require(handoff.state().plan.items.last)
        if let producer {
            let type = try #require(CommandCatalog.standard.command(id: producer.draft.commandID)?.createdObjectType)
            try handoff.plan(.link(item.stamp, .init(results: [parameter: .init(producer: producer.stamp, outputType: type)])))
            item = try #require(handoff.state().plan.items.last)
        }
        return item
    }

    func chain() throws -> [CommandPlanItem] {
        let parent = try queue("todo.create", TaskCreateCommandFixture.arguments("父任务"))
        let child = try queue("subtask.create", [SubtaskCommandFixture.title("子任务")], from: parent, parameter: .parent)
        let title = try queue("subtask.title", [SubtaskCommandFixture.title("新子标题 #新标签")], from: child)
        return [parent, child, title]
    }
    func prepare() throws -> MultiPlanCommandPreview { try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease) }
    func start() throws { try adapter.submit(prepare(), expecting: handoff.owned().lease) }
    func confirm() throws { try adapter.confirmPending(expecting: handoff.owned().lease) }
    func drain() throws {
        for _ in 0..<32 {
            if adapter.pending != nil { try confirm() }
            else if try run.units.contains(where: { $0.state == .ready }) { try adapter.resume(expecting: handoff.owned().lease) }
            else { return }
        }
        Issue.record("有限计划未收敛")
    }
    var run: CommandExecutionRun { get throws { try #require(handoff.state().execution) } }
    func count(_ action: String) -> Int { io.creation.capture.trace.filter { $0 == action }.count }
    func children() throws -> [SubtaskItem] { try context.fetch(FetchDescriptor<SubtaskItem>()) }
}

@MainActor enum MultiPlanRoutineOutputSupport {
    static func adapter(_ fixture: RoutineCreateFixture) -> MultiPlanCommandAdapter {
        .init(coordinator: fixture.handoff.coordinator, adapters: .init(routine: fixture.adapter), outputCapability: .typedCreation)
    }
    @discardableResult static func queue(_ fixture: RoutineCreateFixture, command: String, argument: CommandArgument,
                                        producer: CommandPlanItem) throws -> CommandPlanItem {
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: command), arguments: [argument]))
        let consumer = try #require(fixture.handoff.state().plan.items.last)
        try fixture.handoff.plan(.link(consumer.stamp, .init(results: [.target: .init(producer: producer.stamp, outputType: .routine)])))
        return try #require(fixture.handoff.state().plan.items.last)
    }
}
