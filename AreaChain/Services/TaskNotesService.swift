import Foundation
import SwiftData

/// 待办与习惯备注保存的唯一业务入口：解析备注里的 #标签 合并进对象标签、派生提醒与优先级、关联 @附件。
/// `apply` 只在调用方事务内写入；`save` 给原界面包一次 ModelChanges，保存成功后才请求提醒授权。
/// 上下文、仓储、附件位置与授权请求都由调用方传入，这里不回退到 Persistence.session。
@MainActor enum TaskNotesService {
    /// 附件池的位置；生产默认共享附件目录，隔离环境注入临时根目录。
    struct Attachments {
        var store: AttachmentStore = .shared
        var root: URL?
    }

    /// 备注改写对象的方式：全文替换（原界面）、末尾追加或清空。三者都把最终全文交给同一解析。
    static func update(_ notes: String, parsed: ParsedCapture, tagIDs: String) -> ParsedNoteUpdate {
        ParsedNoteUpdate(
            notes: notes,
            tagIDs: tagIDs,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.hasPriorityToken ? parsed.isImportant : nil,
            isUrgent: parsed.hasPriorityToken ? parsed.isUrgent : nil
        )
    }

    /// 返回解析出的提醒分钟，调用方在保存成功后据此请求授权。
    @discardableResult
    static func apply(_ notes: String, to todo: TodoItem, repository: any TaskRepositoryProtocol,
                      in context: ModelContext, attachments: Attachments = .init()) throws -> Int? {
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let merged = try InputTagResolver.merging(parsed.tagNames, into: todo.tagIDs, in: context)
        try repository.applyParsedNotes(id: todo.id, update: update(notes, parsed: parsed, tagIDs: merged))
        InputAttachmentResolver.linkIfPresent(in: notes, ownerKind: .todo, ownerID: todo.id, context: context,
                                              store: attachments.store, root: attachments.root)
        return parsed.remindMinutes
    }

    @discardableResult
    static func apply(_ notes: String, to routine: DailyRoutine, repository: any RoutineRepositoryProtocol,
                      in context: ModelContext, attachments: Attachments = .init()) throws -> Int? {
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let merged = try InputTagResolver.merging(parsed.tagNames, into: routine.tagIDs, in: context)
        try repository.applyParsedNotes(id: routine.id, update: update(notes, parsed: parsed, tagIDs: merged))
        InputAttachmentResolver.linkIfPresent(in: notes, ownerKind: .routine, ownerID: routine.id, context: context,
                                              store: attachments.store, root: attachments.root)
        return parsed.remindMinutes
    }

    static func save(_ notes: String, for todo: TodoItem, in context: ModelContext,
                     repository: any TaskRepositoryProtocol, requestReminderAccess: (Int?) -> Void) -> Bool {
        var remind: Int?
        let saved = ModelChanges.perform(in: context) {
            remind = try apply(notes, to: todo, repository: repository, in: context)
        }
        if saved { requestReminderAccess(remind) }
        return saved
    }

    static func save(_ notes: String, for routine: DailyRoutine, in context: ModelContext,
                     repository: any RoutineRepositoryProtocol, requestReminderAccess: (Int?) -> Void) -> Bool {
        var remind: Int?
        let saved = ModelChanges.perform(in: context) {
            remind = try apply(notes, to: routine, repository: repository, in: context)
        }
        if saved { requestReminderAccess(remind) }
        return saved
    }
}
