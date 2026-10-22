import AppKit
import SwiftData

/// 唯一装配点的指令部分：各适配器与规格接真实依赖。所有写入只经原仓储与 ModelChanges，保存成功才发布；
/// 设置类沿用当前正式版的偏好权威（AppPreferences 旧键 + LocalSettingCommandAdapter），不切文件后端、不迁移。
extension UnifiedSearchProductionAssembly {
    struct Commands {
        let settings: LocalSettingCommandAdapter
        var taskCreate: TaskCreateCommandAdapter?
        var taskTitle: TaskTitleCommandAdapter?
        var taskField: TaskFieldCommandAdapter?
        var taskChain: TaskChainCommandAdapter?
        var subtask: SubtaskCommandAdapter?
        var routine: RoutineCommandAdapter?
        var batch: BatchCommandAdapter?
        var multiPlan: MultiPlanCommandAdapter?
        var trash: TrashCommandAdapter?
        var taskCopy: TaskCopyCommandAdapter?
        var convert: ConvertCommandAdapter?
        var simple: SimpleCommandAdapter?
        var clipboard: ClipboardCaptureCommandAdapter?
    }

    func makeCommands() throws -> Commands {
        Commands(settings: LocalSettingCommandAdapter(coordinator: coordinator, preferences: services.preferences))
    }

    func makePageCommands() -> WorkspacePageCommands {
        WorkspacePageCommands(router: router, host: hostContext, context: services.context)
    }
}
