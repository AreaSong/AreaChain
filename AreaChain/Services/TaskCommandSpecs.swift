import Foundation
import SwiftData

/// 任务类简单指令的显式装配：仓储、来源证明、附件位置、日期与系统后续都由调用方注入。
/// 只在测试夹具里构造；生产没有构造点。来源、日期与授权请求没有生产默认值，必须显式提供。
@MainActor struct TaskCommandDependencies {
    var tasks: (ModelContext) -> any TaskRepositoryProtocol = { SwiftDataTaskRepository(context: $0) }
    var routines: (ModelContext) -> any RoutineRepositoryProtocol = { SwiftDataRoutineRepository(context: $0) }
    /// 来源所有者给出的普通内容证明；不是 ordinary 时拒绝。备注指令本身处理备注，不要求“无备注”。
    var source: (CommandObjectReference) throws -> CommandTaskTitleEligibility
    var attachments = TaskNotesService.Attachments()
    var today: () -> String
    /// 保存成功后的提醒授权请求；隔离环境注入计数 fake。
    var requestReminderAccess: (Int?) -> Void
    var calendar: Calendar = .current
    /// 协调者的带键摘要；备注基线只存它给出的 HMAC，不存明文。
    var digest: CommandTextDigest
}

/// 任务类简单指令共用的读取与显示规则。
@MainActor enum TaskCommandSpecs {
    /// 可装配的任务类简单指令：三个排序与“昨天全部延至今日”。
    static func all(_ dependencies: TaskCommandDependencies) -> [any SimpleCommandSpec] {
        [SubtaskOrderSpec(dependencies: dependencies), RoutineOrderSpec(dependencies: dependencies),
         DayOrderSpec(dependencies: dependencies), PostponeYesterdaySpec(dependencies: dependencies)]
    }

    /// 备注与快速新增的长文规格：准备期由托管同步读宿主草稿，封存后只剩印记，写入只经一次性借用。
    /// 默认不装配；只在隔离 QA 测试里显式传给 SimpleCommandAdapter，生产没有构造点。
    static func longText(_ dependencies: TaskCommandDependencies) -> [any SimpleCommandSpec] {
        [NotesCommandSpec(kind: .todo, dependencies: dependencies), NotesCommandSpec(kind: .routine, dependencies: dependencies),
         RoutineCaptureSpec(dependencies: dependencies)]
    }

    static func qualify(_ target: CommandObjectReference, _ dependencies: TaskCommandDependencies) throws {
        let source: CommandTaskTitleEligibility
        do { source = try dependencies.source(target) } catch { throw CommandSimpleIssue.invalidTarget(.protectedSource) }
        guard source.protection == .ordinary else { throw CommandSimpleIssue.invalidTarget(.protectedSource) }
    }

    /// 同 UUID 多行或已删除都拒绝，不换成首项。
    static func unique<T: PersistentModel>(_ rows: [T], deletedAt: (T) -> Date?) throws -> T {
        guard let row = rows.first else { throw CommandSimpleIssue.invalidTarget(.missing) }
        guard rows.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        guard deletedAt(row) == nil else { throw CommandSimpleIssue.invalidTarget(.deleted) }
        return row
    }

    static func todo(_ id: UUID, in context: ModelContext) throws -> TodoItem {
        try unique(context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })), deletedAt: \.deletedAt)
    }

    static func routine(_ id: UUID, in context: ModelContext) throws -> DailyRoutine {
        try unique(context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id })), deletedAt: \.deletedAt)
    }

    static func subtask(_ id: UUID, in context: ModelContext) throws -> SubtaskItem {
        try unique(context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })), deletedAt: \.deletedAt)
    }

    /// 1 起的位置参数；0、非整数或越界都拒绝。
    static func position(_ input: CommandResolvedInput, count: Int) throws -> Int {
        guard let argument = input.arguments.first(where: { $0.parameter == .position }), argument.operation == .assign,
              case .number(let raw)? = argument.value, raw.rounded() == raw else { throw CommandSimpleIssue.invalidArguments }
        guard raw >= 1, raw <= Double(count) else { throw CommandSimpleIssue.invalidTarget(.outOfRange) }
        return Int(raw) - 1
    }

    static func positionField(_ index: Int) -> CommandSimpleField {
        .init(id: "position", value: String(index), display: .verbatim(String(index + 1)))
    }

    /// 只给带键摘要（协调者随机内存密钥的 HMAC-SHA256），不存明文；摘要只用于冲突比较，不写日志。
    static func notesField(_ notes: String, _ key: CommandTextDigest) -> CommandSimpleField {
        let digest = key.hex(notes)
        let display: CommandSimpleDisplay = notes.isEmpty ? .localized("unified.simple.value.none")
            : .count("unified.simple.value.characters", notes.count)
        return .init(id: "notes", value: digest, display: display)
    }

    static func remindField(_ minutes: Int?) -> CommandSimpleField {
        guard let minutes else { return .init(id: "remind", value: "none", display: .localized("unified.simple.value.none")) }
        return .init(id: "remind", value: String(minutes), display: .verbatim(String(format: "%02d:%02d", minutes / 60, minutes % 60)))
    }

    static func priorityField(important: Bool, urgent: Bool) -> CommandSimpleField {
        let value = important ? (urgent ? "p1" : "p2") : (urgent ? "p3" : "p4")
        return .init(id: "priority", value: value, display: .localized("command.choice." + value))
    }

    /// 值用标签名字（按对象上的顺序）：新标签保存前没有 UUID，名字才能让预览与写后读取逐字相等。
    static func tagsField(_ names: [String]) -> CommandSimpleField {
        let display: CommandSimpleDisplay = names.isEmpty ? .localized("unified.simple.value.none")
            : .verbatim(names.map { "#" + $0 }.joined(separator: " "))
        return .init(id: "tags", value: names.joined(separator: "\u{1F}"), display: display)
    }

    static func tagNames(_ encoded: String, in context: ModelContext) throws -> [String] {
        let all = try context.fetch(FetchDescriptor<TagItem>())
        return TagIDList.parse(encoded).map { id in all.first { $0.id == id }?.name ?? "?" }
    }
}
