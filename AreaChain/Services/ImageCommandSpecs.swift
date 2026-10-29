import Foundation
import SwiftData

/// 图片附件的简单指令。只接附件中心看得到的普通图片；选图、粘贴、截图（系统面板、截屏与解锁）不在这里。
@MainActor enum ImageCommandSpecs {
    static func all() -> [any SimpleCommandSpec] { [ImageTrashSpec()] }

    /// 同 UUID 唯一的一行附件；删除与否都读（写后核对要读到删除戳）。
    static func attachment(_ id: UUID, in context: ModelContext) throws -> AttachmentItem {
        let rows = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.id == id }))
        guard let row = rows.first else { throw CommandSimpleIssue.invalidTarget(.missing) }
        guard rows.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        return row
    }
}

/// image.trash → AttachmentTrashService.stamp：与详情面板、附件中心的“移到回收站”同一写入（只打删除戳，可恢复）。
/// 资格同附件中心：拥有者已删的孤儿附件不在附件中心里，拒绝；加密或属于敏感手记的附件需要解锁，指令里不认证，一律拒绝。
/// 独立确认，确认面板写明附件归属。
@MainActor struct ImageTrashSpec: SimpleCommandCallSpec {
    let command = CommandID(rawValue: "image.trash")
    let shape = CommandSimpleShape.single(.image)
    let copy = CommandSimpleCopy(preview: "unified.simple.image.trash.preview", saved: "unified.simple.image.trash.saved")
    var confirms: Bool { true }
    var refusesProtectedContent: Bool { true }

    private func eligible(_ call: CommandSimpleCall, in context: ModelContext) throws -> AttachmentItem {
        let row = try ImageCommandSpecs.attachment(call.input.targets.objects[0].id, in: context)
        guard call.frozen == nil else { return row }
        switch try AttachmentTrashService.eligibility(row, in: context) {
        case .eligible: return row
        case .deleted: throw CommandSimpleIssue.invalidTarget(.deleted)
        case .orphan: throw CommandSimpleIssue.invalidTarget(.notListed)
        case .protected: throw CommandSimpleIssue.invalidTarget(.protectedSource)
        }
    }

    private func state(_ row: AttachmentItem, deleted: Bool) -> CommandSimpleState {
        let owner = row.ownerKey.map { "unified.simple.image.owner." + $0.kind.rawValue } ?? "unified.simple.image.owner.none"
        return .init(rows: [.init(key: row.id.uuidString, record: row.persistentModelID, title: row.filename,
                                  fields: [TagOrganizeSpecs.stateField(deleted)])],
                     notices: [.init(key: owner, title: row.filename)])
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let row = try eligible(call, in: context)
        return state(row, deleted: row.deletedAt != nil)
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        state(try eligible(call, in: context), deleted: true)
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        AttachmentTrashService.stamp(try eligible(call, in: context))
    }
}
