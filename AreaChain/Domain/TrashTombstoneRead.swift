import Foundation

enum TrashTombstoneIssue: Equatable {
    case duplicateIdentity, identityNotProvided, identityPartial, invalidCoverage
    case invalidDeletedAt, invalidSubtaskContainer, unknownOwnerKind
    case parentNotProvided, parentPartial, parentMissing, parentAmbiguous, parentInvalid
    case privacyMetadataIncomplete
}

/// 无输入下标、错误原文或被隐藏图片身份；诊断按公开记录及原因去重。
struct TrashTombstoneDiagnostic: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let issue: TrashTombstoneIssue
    let object: CommandObjectReference?
    var description: String { "TrashTombstoneDiagnostic(redacted)" }
    var debugDescription: String { description }
}

enum TrashIndependentDeletion: Equatable { case timestampsDiffer, parentIsLive }

enum TrashDeletionRelation: Equatable {
    case root
    case cascaded(parent: CommandObjectReference)
    case independent(parent: CommandObjectReference, reason: TrashIndependentDeletion)
    case unresolved(parent: CommandObjectReference?, issue: TrashTombstoneIssue)
}

/// 不提供 canRestore：描述既有入口与前提，不能转换成执行资格。
enum TrashIndependentRestore: Equatable {
    case existingEntry
    case notProvided
    case requiresLiveOwner(CommandObjectReference)
    case undetermined
}

struct TrashRestoreConditions: Equatable {
    let independent: TrashIndependentRestore
    let mayRestoreWithParent: CommandObjectReference?
    /// 手记/图片提交需独立核对保护前置；读取层不认证，也不判断授权成功。
    let requiresProtectionCheck: Bool
    var requiresFreshBusinessValidation: Bool { true }
    var provesFileAvailability: Bool { false }
}

/// 复用安全正文分支；隐藏时没有原始正文存储位。
struct TrashDiaryFields: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let dayKey: String
    let createdAt: Date
    let isPinned: Bool
    let tags: [DiaryQueryTag]
    let presentation: DiaryQueryPresentation
    var hasValidTagIDs = true
    var description: String { "TrashDiaryFields(redacted)" }
    var debugDescription: String { description }
}

/// 对象字段入口保留各自类型。todo 的内嵌子项已移出，图片分支只允许公开元数据。
enum TrashObjectFields: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case todo(TodoSnapshot), subtask(SubtaskSnapshot), routine(RoutineSnapshot)
    case diary(TrashDiaryFields), tag(TagQuerySnapshot), image(ImageAttachmentMetadata)
    var description: String { "TrashObjectFields(redacted)" }
    var debugDescription: String { description }
}

struct TrashTombstone: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let deletedAt: Date
    let fields: TrashObjectFields
    let relation: TrashDeletionRelation
    let restoration: TrashRestoreConditions
    /// 同批次唯一父身份核实后的最小属性，不含正文或子项。
    var parentAttributes: ImageOwnerProjection?
    var description: String { "TrashTombstone(redacted)" }
    var debugDescription: String { description }
}

enum TrashMemberReadState: Equatable {
    case notApplicable, notProvided, partial, completeIncludingDeleted, invalid
    /// 图片展示始终受保护边界限制，零个可见成员不证明没有图片。
    case displayLimited
}

struct TrashTombstoneGroup: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let members: [CommandObjectReference]
    let subtaskRead: TrashMemberReadState
    /// 输入枚举声明与展示限制独立；完整输入仍不能用可见成员数推导图片总数。
    let imageInputRead: TrashReadCompleteness?
    let imageRead: TrashMemberReadState
    var visibleMemberCount: Int { members.count }
    var description: String { "TrashTombstoneGroup(redacted)" }
    var debugDescription: String { description }
}

struct TrashTombstoneResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// 每个安全可见对象仅存一份；groups 仅引用身份，供 2H-2 独立命中提升。
    let objects: [TrashTombstone]
    let groups: [TrashTombstoneGroup]
    let diagnostics: [TrashTombstoneDiagnostic]
    /// 只发布类型级读取声明，不回显可能含私密图片 ID 的对象覆盖表。
    let typeCoverage: [CommandObjectType: TrashReadCompleteness]
    var visibleTopLevelCount: Int { groups.count }
    var visibleMemberCount: Int { groups.reduce(0) { $0 + $1.visibleMemberCount } }
    /// 输入声明不证明仓储读取完整；公开结果也不包含受保护图片的数量。
    var countsDescribeVisibleProjectionOnly: Bool { true }
    var description: String { "TrashTombstoneResponse(redacted)" }
    var debugDescription: String { description }
}
