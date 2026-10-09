import Foundation

/// 从原文件后端采样的整组只读预览；执行仍核对签发实例和原单元的接受登记。
struct FileMultiPlanPreview: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let members: [CommandPlanItemStamp]
    let unitID: UUID
    let values: [LocalPreferenceValue]
    let record: LocalPreferenceRecord
}

struct LocalMultiPlanPreview: Equatable {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let value: LocalPreferenceValue
    let current: LocalPreferenceSnapshot
    let evidence: CommandPreferenceBaseline
}
