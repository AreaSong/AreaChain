import Foundation

/// 子项集合包含墓碑；展示只取已通过普通资格核对且实际将完成的子项。
struct CommandTaskCompletionImpact: Equatable {
    struct Child: Equatable {
        let id: UUID
        let parentID: UUID
        let isDone: Bool
        let deletedAt: Date?
        let tagIDs: String
        let title: String
    }
    let original: Bool
    let final: Bool
    let children: [Child]
    var affected: [Child] { !original && final ? children.filter { $0.deletedAt == nil && !$0.isDone } : [] }
}
