import Foundation
import SwiftData

/// 无备注证明的唯一入口。适配器自己读对象备注，用协调者的带键摘要（`simples.textDigest`）
/// 给出证明，不再信任来源所有者的 notes 枚举；只留摘要，不存、不传备注明文。
/// “无备注”与 TaskCopyContent.notes 同口径：去掉首尾空白后为空。
@MainActor enum CommandNotesProofReader {
    /// 放宽“普通无备注”门槛的指令（用户 2026-10-20 确认）：字段类不读写备注；回收、转换在确认面板列出备注去向；
    /// 复制本就包含备注。不在此列的一律仍要求无备注——尤其 todo.title／subtask.title：标题里 `//` 派生备注另行定界
    /// （见 docs/unified-search-commands.md 的“普通无备注”门槛）；完成、建标签与子任务类指令未列入，保持原门槛。
    static let allowsNotes: Set<String> = [
        "todo.move", "todo.priority", "todo.reminder", "todo.tags", "todo.due", "batch.move", "batch.tags",
        "todo.trash", "routine.trash", "batch.trash", "todo.toRoutine", "routine.toTodo", "todo.copy",
    ]

    /// unproven 一律不放行；unreadable 交给调用方原有的缺失／重复检查（它们必然拒绝）；有备注只放行上列指令。
    static func admits(_ command: String, _ proof: CommandNotesProof) -> Bool {
        switch proof {
        case .unproven: return false
        case .unreadable, .absent: return true
        case .present: return allowsNotes.contains(command)
        }
    }

    static func proof(_ notes: String, key: CommandTextDigest) -> CommandNotesProof {
        let digest = key.hex(notes)
        return TaskCopyContent.notes(notes) == nil ? .absent(digest: digest) : .present(digest: digest)
    }

    /// 只读待办或习惯本身的备注（子任务指令传父待办）；子任务没有备注字段，存在即证明为无备注。
    /// 没有密钥为 unproven，读不到唯一对象为 unreadable。
    static func proof(of target: CommandObjectReference, in context: ModelContext,
                      key: CommandTextDigest?) -> CommandNotesProof {
        guard let key else { return .unproven }
        let id = target.id
        do {
            switch target.type {
            case .todo:
                let rows = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
                return rows.count == 1 ? proof(rows[0].notes, key: key) : .unreadable
            case .routine, .routineOccurrence:
                // 执行实例的 id 是习惯定义的 UUID（routineOccurrence 身份），备注属于定义本身。
                let rows = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
                return rows.count == 1 ? proof(rows[0].notes, key: key) : .unreadable
            case .subtask:
                let rows = try context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id }))
                return rows.count == 1 ? proof("", key: key) : .unreadable
            default: return .unproven
            }
        } catch { return .unreadable }
    }

    /// 冻结指纹不留备注明文（放宽后对象可能带备注）；备注变化由资格里的带键摘要比较。
    static func redacted(_ snapshot: TodoSnapshot) -> TodoSnapshot {
        var copy = snapshot
        copy.notes = ""
        return copy
    }

    static func redacted(_ snapshot: RoutineSnapshot) -> RoutineSnapshot {
        var copy = snapshot
        copy.notes = ""
        return copy
    }

    /// 所有者给的普通证明加上适配器自读的备注证明；之后的相等比较同时覆盖来源修订与备注。
    static func proving(_ source: CommandTaskTitleEligibility, of target: CommandObjectReference,
                        in context: ModelContext, key: CommandTextDigest?) -> CommandTaskTitleEligibility {
        var proven = source
        proven.notes = proof(of: target, in: context, key: key)
        return proven
    }
}
