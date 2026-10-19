import Foundation
import SwiftData

/// 快速新增重复事项的唯一业务入口：一行文字经 NaturalLanguageParser.parseTaskCapture 得到标题、提醒、优先级、
/// #标签与备注，标签沿 InputTagResolver（名字匹配、恢复墓碑或新建），@附件沿 InputAttachmentResolver。
/// `apply` 只在调用方事务内写入；`capture` 给原界面包一次 ModelChanges，保存成功后才请求提醒授权。
@MainActor enum RoutineCaptureService {
    struct Request {
        var text: String
        var sortOrder: Int
        /// 指令在接受前分配的新习惯身份；原界面不传，由仓储生成。
        var creationID: UUID?
        /// 原界面沿 CreateRoutineParams 的默认（当天）；隔离环境注入固定日期。
        var createdDayKey: String = DayKey.today()
    }

    /// 修剪后为空不新建；与原界面一致。
    static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// 返回新习惯与解析出的提醒分钟。
    static func apply(_ request: Request, repository: any RoutineRepositoryProtocol, in context: ModelContext,
                      attachments: TaskNotesService.Attachments = .init()) throws -> (DailyRoutine, Int?) {
        guard let text = trimmed(request.text) else { throw RepositoryError.invalidArgument("习惯标题不能为空") }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let ids = try InputTagResolver.resolve(parsed.tagNames, in: context)
        let routine = try repository.addRoutine(CreateRoutineParams(
            title: parsed.cleanTitle, sortOrder: request.sortOrder, remindMinutes: parsed.remindMinutes,
            tagIDs: ids, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent, notes: parsed.notes,
            createdDayKey: request.createdDayKey, creationID: request.creationID
        ))
        InputAttachmentResolver.linkIfPresent(in: text, ownerKind: .routine, ownerID: routine.id, context: context,
                                              store: attachments.store, root: attachments.root)
        return (routine, parsed.remindMinutes)
    }

    static func capture(_ request: Request, in context: ModelContext, repository: any RoutineRepositoryProtocol,
                        requestReminderAccess: (Int?) -> Void) -> Bool {
        guard trimmed(request.text) != nil else { return false }
        var remind: Int?
        let saved = ModelChanges.perform(in: context) {
            remind = try apply(request, repository: repository, in: context).1
        }
        if saved { requestReminderAccess(remind) }
        return saved
    }
}
