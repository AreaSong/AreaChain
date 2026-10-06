import Foundation
import SwiftData

/// 普通捕获的唯一业务入口；结构化指令、剪贴板和习惯不共享此输入语义。
@MainActor
enum TaskMutationService {
    struct CaptureInput {
        let text: String
        let dayKey: String
        var tagIDs: [UUID] = []
        var fallbackQuadrant: QuadrantSlot?
        var creationID: UUID?
    }

    @MainActor
    struct Dependencies {
        var sourceBundleID: @MainActor () -> String
        var repository: @MainActor (ModelContext) -> any TaskRepositoryProtocol
        var transaction: ModelChanges.Boundary
        var registerLocalCreation: @MainActor (UUID) throws -> Void
        var requestReminderAccessIfNeeded: @MainActor (Int?) -> Void
        var validateBeforeTransaction: @MainActor () throws -> Void = {}

        static var production: Dependencies {
            Dependencies(
                sourceBundleID: { CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp) },
                repository: { SwiftDataTaskRepository(context: $0) },
                transaction: ModelChanges.Boundary(),
                registerLocalCreation: { _ in },
                requestReminderAccessIfNeeded: { minutes in
                    if minutes != nil { NotificationScheduler.shared.ensureAuthorization() }
                }
            )
        }
    }

    enum LocalState { case emptyInput, pending, notSubmitted, commitUnknown, saved }

    /// 同步返回的句柄在外层结束后更新；只有 savedID 可作为已创建输出。
    /// candidateID 仅为内存对象身份，未知结果不得据此重试创建。
    @MainActor
    final class Creation {
        fileprivate(set) var candidateID: UUID?
        fileprivate(set) var savedID: UUID?
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var rejected = false
        fileprivate(set) var emptyInput = false

        var state: LocalState {
            if emptyInput { return .emptyInput }
            if savedID != nil { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .commitUnknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }

        // 只供旧 UI 的同步顶层调用；嵌套句柄不能提前触发清稿。
        var saved: Bool { state == .saved }
    }

    /// 后续命令须在进入前拒绝 context.hasChanges，不能用新 context 隐藏 pending 编辑。
    static func createCaptured(
        _ input: CaptureInput, in context: ModelContext, dependencies: Dependencies
    ) -> Creation {
        let result = Creation()
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { result.emptyInput = true; return result }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        do {
            // 命令的最终检查必须先于 ModelChanges 的原有预保存；旧 UI 默认无附加守卫。
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction,
                                         observe: { result.transaction = $0 }) {
                let ids = try InputTagResolver.merging(parsed.tagNames, into: TagIDList.encode(input.tagIDs), in: context)
                let params = CreateTodoParams(
                    title: parsed.cleanTitle, dayKey: input.dayKey, notes: parsed.notes,
                    remindMinutes: parsed.remindMinutes,
                    isImportant: parsed.hasPriorityToken ? parsed.isImportant : (input.fallbackQuadrant?.isImportant ?? parsed.isImportant),
                    isUrgent: parsed.hasPriorityToken ? parsed.isUrgent : (input.fallbackQuadrant?.isUrgent ?? parsed.isUrgent),
                    tagIDs: TagIDList.parse(ids), sourceBundleID: dependencies.sourceBundleID(),
                    creationID: input.creationID
                )
                let todo = try dependencies.repository(context).addTodo(params)
                result.candidateID = todo.id
                registerCompletion(result, id: todo.id, minutes: parsed.remindMinutes,
                                   context: context, dependencies: dependencies)
            }
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }

    private static func registerCompletion(
        _ result: Creation, id: UUID, minutes: Int?, context: ModelContext, dependencies: Dependencies
    ) {
        ModelChanges.afterCommit(in: context) {
            result.savedID = id
            do { try dependencies.registerLocalCreation(id) }
            catch {
                result.registrationFailed = true
                ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
            }
        }
        ModelChanges.afterPublication(in: context) {
            dependencies.requestReminderAccessIfNeeded(minutes)
        }
    }
}
