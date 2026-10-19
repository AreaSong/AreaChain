import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// T-M6 任务类简单指令的隔离夹具：内存库、私有事件、计数 fake 刷新与授权、临时附件目录、固定今天。
/// 七个任务类规格只在这里显式打开；来源证明默认 ordinary，可逐对象改为受保护。
@MainActor final class TaskSimpleFixture {
    static let today = "2026-10-19"
    static let yesterday = "2026-10-18"
    let io: TaskCaptureFixture
    let handoff: HandoffFixture
    let root: URL
    var saveMode = TaskCreateCommandIO.SaveMode.normal
    var beforeTransaction: (() throws -> Void)?
    var refreshes: [Bool] = []
    var authorizations: [Int?] = []
    var protected: Set<UUID> = []
    var tasks: (ModelContext) -> any TaskRepositoryProtocol = { SwiftDataTaskRepository(context: $0) }
    private(set) var environment: SimpleCommandEnvironment!
    private(set) var adapter: SimpleCommandAdapter!
    var context: ModelContext { io.context }
    var attachments: TaskNotesService.Attachments { .init(store: AttachmentStore(root: root), root: root) }

    init(capability: SimpleCommandAdapter.Capability = .open) throws {
        io = try TaskCaptureFixture()
        handoff = try HandoffFixture()
        root = FileManager.default.temporaryDirectory
            .appending(path: "areachain-tm6-\(UUID().uuidString)", directoryHint: .isDirectory)
        var boundary = io.boundary
        boundary.save = { [unowned self] context in
            io.trace.append("save")
            if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        environment = try .init(context: context, center: io.center, dependencies: .init(
            transaction: boundary, validateBeforeTransaction: { [unowned self] in try beforeTransaction?() },
            registerLocalModification: { [unowned self] in io.trace.append("fact") },
            refresh: { [unowned self] includeCalendar in refreshes.append(includeCalendar) }))
        adapter = .init(coordinator: handoff.coordinator, environment: environment,
                        specs: TaskCommandSpecs.all(dependencies), capability: capability)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    var dependencies: TaskCommandDependencies {
        .init(tasks: { [unowned self] in tasks($0) },
              source: { [unowned self] target in
                  .init(revision: UUID(), protection: protected.contains(target.id) ? .required : .ordinary, notes: .unknown)
              },
              attachments: attachments, today: { Self.today },
              requestReminderAccess: { [unowned self] minutes in authorizations.append(minutes) },
              calendar: Self.calendar)
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    @discardableResult func insert<T: PersistentModel>(_ model: T) throws -> T {
        context.insert(model)
        try context.save()
        return model
    }

    func notes(_ operation: CommandFieldOperation, _ text: String? = nil) -> CommandArgument {
        .init(parameter: .notes, operation: operation, value: text.map { .longText($0) })
    }
    func position(_ value: Double) -> CommandArgument { .init(parameter: .position, operation: .assign, value: .number(value)) }
    func day(_ value: String) -> CommandArgument { .init(parameter: .day, operation: .assign, value: .day(value)) }
    func parent(_ todo: TodoItem) -> CommandArgument {
        .init(parameter: .parent, operation: .assign, value: .object(.init(type: .todo, id: todo.id)))
    }
    func body(_ text: String) -> CommandArgument { .init(parameter: .body, operation: .replace, value: .longText(text)) }

    func queue(_ command: String, targets: [CommandObjectReference] = [], single: Bool = true,
               arguments: [CommandArgument] = []) throws {
        let selection: CommandDraftTargets = targets.isEmpty ? .none
            : .init(targets.count == 1 && single ? .single : .selected, objects: targets)
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
                                targets: selection, arguments: arguments))
    }
    func preview() throws -> CommandSimplePreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept() throws -> CommandSimpleAcceptance { try adapter.accept(preview(), expecting: handoff.owned().lease) }
    func submit(_ accepted: CommandSimpleAcceptance) throws -> CommandSimpleFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func run(_ command: String, targets: [CommandObjectReference] = [], single: Bool = true,
             arguments: [CommandArgument] = []) throws -> (CommandSimpleAcceptance, CommandSimpleFacts) {
        try queue(command, targets: targets, single: single, arguments: arguments)
        let accepted = try accept()
        return (accepted, try submit(accepted))
    }
    func verify() throws -> CommandSimpleVerification {
        let run = try #require(handoff.state().execution)
        let operation = try #require(run.snapshot.items.first.flatMap { run.operation($0.id) })
        return try adapter.verifyUnknown(operation, expecting: handoff.owned().lease)
    }
    func count(_ action: String) -> Int { io.trace.filter { $0 == action }.count }
    /// 同容器的新 context：读出真实落盘结果。
    func stored<T: PersistentModel>(_ type: T.Type) throws -> [T] { try ModelContext(io.container).fetch(FetchDescriptor<T>()) }
    func changedFields(_ state: (CommandSimpleState, CommandSimpleState)) -> [String] {
        state.0.changes(to: state.1).map { $0.key.prefix(4) == "tag:" ? "tag" : $0.field }
    }
}

/// 备注与快速新增的规格暂不装配（长文受导出守卫）：测试直接运行规格，流程与骨架相同——
/// 读当前值、推出保存后的值、在一次事务内写入并按冻结行再读核对，保存成功后才发出系统后续。
extension TaskSimpleFixture {
    struct SpecRun {
        let before: CommandSimpleState
        let after: CommandSimpleState
        let followUp: Bool
    }

    func pending(_ command: String) throws -> any SimpleCommandSpec {
        try #require(TaskCommandSpecs.pendingLongText(dependencies).first { $0.command.rawValue == command })
    }

    func input(_ targets: [CommandObjectReference] = [], _ arguments: [CommandArgument]) -> CommandResolvedInput {
        .init(arguments: arguments, targets: targets.isEmpty ? .none : .init(targets.count == 1 ? .single : .selected, objects: targets))
    }

    func preview(_ spec: any SimpleCommandSpec, _ call: CommandSimpleCall) throws -> (CommandSimpleState, CommandSimpleState) {
        let before = try spec.observe(call, in: context)
        return (before, try spec.expect(call, from: before, in: context))
    }

    func runSpec(_ spec: any SimpleCommandSpec, _ call: CommandSimpleCall) throws -> SpecRun {
        let (before, after) = try preview(spec, call)
        let frozen = CommandSimpleCall(input: call.input, creation: call.creation, frozen: before.keys.union(after.keys))
        try ModelChanges.transaction(in: context, boundary: environment.dependencies.transaction) {
            try spec.apply(frozen, in: context)
            guard try spec.observe(frozen, in: context) == after else { throw CommandSimpleIssue.invalidTarget(.changed) }
        }
        return .init(before: before, after: after, followUp: spec.afterSave(frozen, in: context))
    }
}
