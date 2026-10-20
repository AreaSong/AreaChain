import Foundation
import SwiftData

/// 合并批 M-3 C：回收站恢复的唯一写入。回收站页（DayBoardMutations.restore*）与 trash.restore 共用：
/// 待办连同同一删除戳的子任务与附件、习惯与手记连同附件、标签，都只调原仓储的 restore*；
/// 附件只能在拥有者仍在时单独恢复（孤儿附件拒绝，同回收站页 canRestore 与 AttachmentAccess 的拥有者判定）。
@MainActor struct TrashRestoreService {
    enum Refusal: Error, Equatable { case ownerDeleted, unsupported, missing }

    static let types: Set<CommandObjectType> = [.todo, .routine, .diary, .image, .tag]

    var tasks: any TaskRepositoryProtocol
    var routines: any RoutineRepositoryProtocol
    var diaries: any DiaryRepositoryProtocol
    var catalog: any CatalogRepositoryProtocol

    /// context 只用于附件（拥有者判定）；其余类型由仓储自己的 context 读写。
    func restore(_ object: CommandObjectReference, in context: ModelContext? = nil) throws {
        switch object.type {
        case .todo: try tasks.restoreTodo(id: object.id)
        case .routine: try routines.restoreRoutine(id: object.id)
        case .diary: try diaries.restoreDiary(id: object.id)
        case .tag: try catalog.restoreTag(id: object.id)
        case .image:
            let id = object.id
            guard let context, let item = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.id == id })).first else {
                throw Refusal.missing
            }
            try Self.restoreAttachment(item, in: context)
        default: throw Refusal.unsupported
        }
    }

    static func restoreAttachment(_ item: AttachmentItem, in context: ModelContext) throws {
        guard let owner = item.ownerKey, try AttachmentAccess.ownerIsLive(owner, context: context) else {
            throw Refusal.ownerDeleted
        }
        item.deletedAt = nil
    }
}
