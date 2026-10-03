import Foundation

/// 完整表示声明范围内含活行和墓碑的全部同身份记录，不证明真实库已读取。
enum TrashReadCompleteness: Equatable { case notProvided, partial, completeIncludingDeleted, invalid }

struct TrashMemberScope: Hashable {
    let parent: CommandObjectReference
    let memberType: CommandObjectType
}

/// 对象/成员范围优先于整类型声明。按父项取全子项不等于跨父项完成 ID 唯一性读取。
struct TrashReadCoverage: Equatable {
    var types: [CommandObjectType: TrashReadCompleteness] = [:]
    var objects: [CommandObjectReference: TrashReadCompleteness] = [:]
    var members: [TrashMemberScope: TrashReadCompleteness] = [:]
    var diaryPrivacy = ImageOwnerCoverage()

    func identity(_ id: CommandObjectReference) -> TrashReadCompleteness {
        objects[id] ?? types[id.type] ?? .notProvided
    }

    func children(of parent: CommandObjectReference, type: CommandObjectType) -> TrashReadCompleteness {
        members[.init(parent: parent, memberType: type)] ?? types[type] ?? .notProvided
    }
}

/// 只消费注入值。subtasks 可补孤立行；todos 内嵌子项也参与身份核验，勿重复投递同一行。
/// nil 与 [] 分别表示未提供和已提供空集合；是否完整仍由 coverage 独立声明。
struct TrashTombstoneInput: CustomStringConvertible, CustomDebugStringConvertible {
    var todos: [TodoSnapshot]?
    var subtasks: [SubtaskSnapshot]?
    /// 原始无父引用行没有可构造的 SubtaskSnapshot；仍参与同类型身份隔离。
    var unconvertedSubtaskIDs: [UUID] = []
    var routines: [RoutineSnapshot]?
    var diaries: [DiarySnapshot]?
    var tags: [TagQuerySnapshot]?
    var images: [ImageAttachmentMetadata]?
    var privacy = DiaryQueryMetadata(tagNames: nil, privateTagIDs: nil)
    /// 存储适配显式提供对象级保护事实；旧纯值输入仍沿原正文投影判定。
    var diaryProtection: DiaryImageProtectionFacts?
    var coverage = TrashReadCoverage()
    var locale = Locale(identifier: "en")

    func isProvided(_ type: CommandObjectType) -> Bool {
        switch type {
        case .todo: todos != nil
        case .subtask: subtasks != nil || todos != nil
        case .routine: routines != nil
        case .diary: diaries != nil
        case .tag: tags != nil
        case .image: images != nil
        default: false
        }
    }

    var description: String { "TrashTombstoneInput(redacted)" }
    var debugDescription: String { description }
}

/// 原始字段只在本次读取内部使用；安全输出不持有该枚举或完整 request。
enum TrashInputValue: CustomStringConvertible, CustomDebugStringConvertible {
    case todo(TodoSnapshot), subtask(SubtaskSnapshot), routine(RoutineSnapshot)
    case diary(DiarySnapshot), tag(TagQuerySnapshot), image(ImageAttachmentMetadata)

    var id: CommandObjectReference {
        switch self {
        case .todo(let value): .init(type: .todo, id: value.id)
        case .subtask(let value): .init(type: .subtask, id: value.id)
        case .routine(let value): .init(type: .routine, id: value.id)
        case .diary(let value): .init(type: .diary, id: value.id)
        case .tag(let value): .init(type: .tag, id: value.id)
        case .image(let value): .init(type: .image, id: value.id)
        }
    }

    var deletedAt: Date? {
        switch self {
        case .todo(let value): value.deletedAt
        case .subtask(let value): value.deletedAt
        case .routine(let value): value.deletedAt
        case .diary(let value): value.deletedAt
        case .tag(let value): value.deletedAt
        case .image(let value): value.deletedAt
        }
    }

    var parent: CommandObjectReference? {
        switch self {
        case .subtask(let value): .init(type: .todo, id: value.todoId)
        case .image(let value): value.ownerKey.map { .init(type: $0.kind.commandType, id: $0.id) }
        default: nil
        }
    }

    var description: String { "TrashInputValue(redacted)" }
    var debugDescription: String { description }
}

extension AttachmentOwner {
    var commandType: CommandObjectType {
        switch self {
        case .todo: .todo
        case .routine: .routine
        case .diary: .diary
        }
    }
}
