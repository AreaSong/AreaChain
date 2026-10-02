import Foundation

/// completeIncludingDeleted 是调用方对指定范围的声明，不证明真实仓储已读取。
enum ImageReadCompleteness: Equatable {
    case notProvided, partial, completeIncludingDeleted, invalid
}

/// 对象声明优先于类型声明；显式局部缺口不会被更宽的完整声明掩盖。
struct ImageOwnerCoverage: Equatable {
    var types: [AttachmentOwner: ImageReadCompleteness] = [:]
    var objects: [AttachmentOwnerKey: ImageReadCompleteness] = [:]

    func state(for owner: AttachmentOwnerKey) -> ImageReadCompleteness {
        objects[owner] ?? types[owner.kind] ?? .notProvided
    }
}

/// 图片 ID 在所有类型/拥有者之间唯一。按拥有者读全附件不等于按图片 ID 查全重复行。
struct ImageIdentityCoverage: Equatable {
    var allIDs: ImageReadCompleteness = .notProvided
    var ids: [UUID: ImageReadCompleteness] = [:]

    func state(for id: UUID) -> ImageReadCompleteness { ids[id] ?? allIDs }
}

struct ImageAssociationCoverage: Equatable {
    var owners = ImageOwnerCoverage()
    var associations = ImageOwnerCoverage()
    var imageIdentities = ImageIdentityCoverage()
    /// 只适用于 diary；包含相关已删除标签、私密标签集合和正文保护判定所需事实。
    var diaryPrivacy = ImageOwnerCoverage()
}

enum ImageProtection: Equatable { case unprotected, protected, unknown }

/// AttachmentRef 缺创建/删除/公开归属，ExportedAttachment 丢失保护来源，均不能独立证明可浏览。
/// 只保留 privacyVaultID 是否存在，不携带库标识、存储位置、文件 URL 或访问能力。
struct ImageAttachmentMetadata: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    var ownerKind: String
    var ownerID: UUID
    var filename: String
    var createdAt: Date
    var deletedAt: Date?
    var protection: ImageProtection

    var ownerKey: AttachmentOwnerKey? {
        AttachmentOwner(rawValue: ownerKind).map { .init(kind: $0, id: ownerID) }
    }
    var description: String { "ImageAttachmentMetadata(redacted)" }
    var debugDescription: String { description }
}

struct ImageOwnerSnapshots: CustomStringConvertible, CustomDebugStringConvertible {
    var todos: [TodoSnapshot]?
    var routines: [RoutineSnapshot]?
    var diaries: [DiarySnapshot]?

    var description: String { "ImageOwnerSnapshots(redacted)" }
    var debugDescription: String { description }
}

struct ImageAssociationRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let images: [ImageAttachmentMetadata]?
    let owners: ImageOwnerSnapshots
    let privacy: DiaryQueryMetadata
    let coverage: ImageAssociationCoverage

    var description: String { "ImageAssociationRequest(redacted)" }
    var debugDescription: String { description }
}

enum ImageAssociationIssue: Equatable {
    case ownerNotProvided, ownerCoverageIncomplete, invalidOwnerData
    case duplicateOwnerID, missingOwner, deletedOwner, unknownOwnerKind
    case imagesNotProvided, associationCoverageIncomplete, invalidAssociationData
    case duplicateImageID, imageIdentityIncomplete, invalidImageIdentity, deletedImage
    case invalidImageMetadata, invalidOwnerAttributes, privacyMetadataIncomplete
}

/// 不保存图片 ID、原始 ownerKind、输入位置或错误原文，避免受保护行的数量/内容进入诊断。
struct ImageAssociationDiagnostic: Equatable {
    let issue: ImageAssociationIssue
    let owner: AttachmentOwnerKey?
}

enum ImageOwnerState: Equatable { case live, missing, deleted, ambiguous, unknown }

/// protected 不表达数量或确定有无；不能映射成普通 has:image 的 true/false。
enum ImageAssociationPresence: Equatable { case present, absent, unknown, protected }

enum ImageBrowseState: Equatable { case available, unavailable, unknown, protected }

struct ImageOwnerAssociation: Equatable {
    let owner: AttachmentOwnerKey
    let ownerState: ImageOwnerState
    let presence: ImageAssociationPresence
    let browse: ImageBrowseState
}

/// 可浏览元数据仍不证明文件存在/可读；拥有者属性只在 response.owners 保存一份。
struct ImageBrowseProjection: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let owner: AttachmentOwnerKey
    let filename: String
    let createdAt: Date

    var description: String { "ImageBrowseProjection(redacted)" }
    var debugDescription: String { description }
}

struct ImageAssociationResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var associations: [AttachmentOwnerKey: ImageOwnerAssociation] = [:]
    var owners: [AttachmentOwnerKey: ImageOwnerProjection] = [:]
    var images: [ImageBrowseProjection] = []
    var diagnostics: [ImageAssociationDiagnostic] = []

    /// 未请求/未覆盖的对象不能借其他对象的完整性推导 absent。
    func association(for owner: AttachmentOwnerKey) -> ImageOwnerAssociation {
        associations[owner] ?? .init(owner: owner, ownerState: .unknown, presence: .unknown, browse: .unknown)
    }
    var description: String { "ImageAssociationResponse(redacted)" }
    var debugDescription: String { description }
}
