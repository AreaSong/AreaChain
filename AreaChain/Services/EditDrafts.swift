import Foundation
import Observation

/// 保存失败的备注只保留在本次运行中，切换检查器不会丢失，也不会额外写入敏感内容副本。
@Observable
@MainActor
final class EditDrafts {
    static let shared = EditDrafts()
    var titles: [String: String] = [:]
    var notes: [String: String] = [:]

    /// 详情编辑草稿的键：待办标题与备注共用“todo-<id>”，子任务标题为“subtask-<id>”。
    /// 编辑器与取消标题指令（合并批 M-1 C）都从这里取，不各写一份格式。
    static func key(todo id: UUID) -> String { "todo-\(id)" }
    static func key(subtask id: UUID) -> String { "subtask-\(id)" }

    func discard(owner: AttachmentOwnerKey) {
        titles.removeValue(forKey: "\(owner.kind.rawValue)-\(owner.id)")
        notes.removeValue(forKey: "\(owner.kind.rawValue)-\(owner.id)")
    }
}
