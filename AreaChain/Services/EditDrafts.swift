import Foundation
import Observation

/// 保存失败的备注只保留在本次运行中，切换检查器不会丢失，也不会额外写入敏感内容副本。
@Observable
@MainActor
final class EditDrafts {
    static let shared = EditDrafts()
    var notes: [String: String] = [:]

    func discard(owner: AttachmentOwnerKey) {
        notes.removeValue(forKey: "\(owner.kind.rawValue)-\(owner.id)")
    }
}
