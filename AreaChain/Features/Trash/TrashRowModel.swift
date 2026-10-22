import Foundation
import SwiftData
import SwiftUI

enum TrashViewMode: String, CaseIterable, Hashable {
    case split
    case grid
    case list
}

enum TrashCategoryFilter: String, CaseIterable, Hashable {
    case all
    case todo
    case routine
    case diary
    case attachment
    case tag

    var section: TrashSection? {
        switch self {
        case .all: nil
        case .todo: .todo
        case .routine: .routine
        case .diary: .diary
        case .attachment: .attachment
        case .tag: .tag
        }
    }

    var titleKey: String {
        switch self {
        case .all: "clipboard.filter.all"
        case .todo: "trash.kind.todo"
        case .routine: "trash.kind.resident"
        case .diary: "trash.kind.diary"
        case .attachment: "trash.kind.attachment"
        case .tag: "trash.kind.tag"
        }
    }
}

enum TrashSection: CaseIterable, Hashable {
    case todo
    case routine
    case diary
    case attachment
    case tag

    var titleKey: LocalizedStringKey {
        switch self {
        case .todo: "trash.kind.todo"
        case .routine: "trash.kind.resident"
        case .diary: "trash.kind.diary"
        case .attachment: "trash.kind.attachment"
        case .tag: "trash.kind.tag"
        }
    }

    var iconName: String {
        switch self {
        case .todo: "checkmark.circle"
        case .routine: "repeat"
        case .diary: "note.text"
        case .attachment: "paperclip"
        case .tag: "tag"
        }
    }
}

struct TrashTagSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let colorToken: String

    static func resolve(tagIDs: String, from catalog: [TagItem]) -> [TrashTagSummary] {
        let ids = TagIDList.parse(tagIDs)
        guard !ids.isEmpty else { return [] }
        let byID = Dictionary( catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { id in
            guard let tag = byID[id] else { return nil }
            return TrashTagSummary(id: tag.id, name: tag.name, colorToken: tag.colorToken)
        }
    }
}

struct TrashSubtaskSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let isDone: Bool
}

struct TrashTodoDetail {
    let dayKey: String
    let notes: String
    let isDone: Bool
    let isImportant: Bool
    let isUrgent: Bool
    let remindMinutes: Int?
    let dueMinutes: Int?
    let subtasks: [TrashSubtaskSummary]
    let tags: [TrashTagSummary]
    let attachmentCount: Int
    let createdAt: Date

    var quadrantSlot: QuadrantSlot {
        QuadrantSlot.of(important: isImportant, urgent: isUrgent)
    }

    var completedSubtaskCount: Int {
        subtasks.filter(\.isDone).count
    }
}

struct TrashRoutineDetail {
    let weekdayMask: Int
    let notes: String
    let isEnabled: Bool
    let isImportant: Bool
    let isUrgent: Bool
    let remindMinutes: Int?
    let tags: [TrashTagSummary]
    let attachmentCount: Int
    let createdAt: Date

    var quadrantSlot: QuadrantSlot {
        QuadrantSlot.of(important: isImportant, urgent: isUrgent)
    }
}

struct TrashDiaryDetail {
    let dayKey: String
    let isPinned: Bool
    let isPrivateProvider: () -> Bool
    let fullTextProvider: () -> String
    let tagsProvider: () -> [TrashTagSummary]
    let attachmentCount: Int
    let createdAt: Date
}

struct TrashAttachmentDetail {
    let reference: AttachmentRef
    let isPrivate: Bool
    let ownerKind: AttachmentOwner?
    let ownerTitle: String?
    let ownerDeleted: Bool
    let createdAt: Date
}

struct TrashTagDetail {
    let colorToken: String
    let isDiaryPreset: Bool
    let isPrivateDiary: Bool
}

enum TrashItemDetail {
    case todo(TrashTodoDetail)
    case routine(TrashRoutineDetail)
    case diary(TrashDiaryDetail)
    case attachment(TrashAttachmentDetail)
    case tag(TrashTagDetail)
}

@MainActor
struct TrashRow: Identifiable {
    var id: UUID
    var title: String
    var section: TrashSection
    var kindLabel: LocalizedStringKey
    var isResident: Bool
    var deletedAt: Date
    var restore: @MainActor () -> Void
    var purge: @MainActor () -> Bool
    /// 隔离宿主没有附件存储时为 false：清除会级联删附件文件，不能落到共享目录（§9.102）。
    var canPurge: Bool = true
    var removeFromStore: @MainActor (ModelContext) throws -> Void
    var purgesOwner: AttachmentOwnerKey? = nil
    var skipIfOwnerPurged: AttachmentOwnerKey? = nil
    var canRestore: Bool = true
    var titleProvider: (() -> String)? = nil
    var filesToRemove: [UUID] = []
    var detail: TrashItemDetail? = nil

    var displayTitle: String { titleProvider?() ?? title }

    static func resident(_ item: DailyRoutine, attachments: [AttachmentItem], tags: [TagItem] = [],
                         attachmentStore: AttachmentStore? = .shared) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        let ownerKey = AttachmentOwnerKey(kind: .routine, id: item.id)
        let ownedFiles = attachments.filter { $0.ownerKey == ownerKey }.map(\.id)
        let detail = TrashRoutineDetail(
            weekdayMask: item.resolvedWeekdayMask,
            notes: item.notes,
            isEnabled: item.isEnabled,
            isImportant: item.isImportant,
            isUrgent: item.isUrgent,
            remindMinutes: item.remindMinutes,
            tags: TrashTagSummary.resolve(tagIDs: item.tagIDs, from: tags),
            attachmentCount: ownedFiles.count,
            createdAt: item.createdAt
        )
        return TrashRow(
            id: item.id,
            title: item.title,
            section: .routine,
            kindLabel: "trash.kind.resident",
            isResident: true,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreRoutine(item) },
            purge: { attachmentStore.map { DayBoardMutations.purgeRoutine(item, attachments: $0) } ?? false },
            canPurge: attachmentStore != nil,
            removeFromStore: { context in
                try DayBoardMutations.routineRepo(for: context).deleteRoutine(id: item.id, soft: false)
            },
            purgesOwner: ownerKey,
            filesToRemove: ownedFiles,
            detail: .routine(detail)
        )
    }

    static func todo(_ item: TodoItem, attachments: [AttachmentItem], tags: [TagItem] = [],
                     attachmentStore: AttachmentStore? = .shared) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        let ownerKey = AttachmentOwnerKey(kind: .todo, id: item.id)
        let ownedFiles = attachments.filter { $0.ownerKey == ownerKey }.map(\.id)
        let subtasks = item.subtasks
            .filter { $0.deletedAt == nil || SoftDelete.shouldRestoreChild(parentDeletedAt: deletedAt, childDeletedAt: $0.deletedAt) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { TrashSubtaskSummary(id: $0.id, title: $0.title, isDone: $0.isDone) }
        let detail = TrashTodoDetail(
            dayKey: item.dayKey,
            notes: item.notes,
            isDone: item.isDone,
            isImportant: item.isImportant,
            isUrgent: item.isUrgent,
            remindMinutes: item.remindMinutes,
            dueMinutes: item.dueMinutes,
            subtasks: subtasks,
            tags: TrashTagSummary.resolve(tagIDs: item.tagIDs, from: tags),
            attachmentCount: ownedFiles.count,
            createdAt: item.createdAt
        )
        return TrashRow(
            id: item.id,
            title: item.title,
            section: .todo,
            kindLabel: "trash.kind.todo",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreTodo(item) },
            purge: { attachmentStore.map { DayBoardMutations.purgeTodo(item, attachments: $0) } ?? false },
            canPurge: attachmentStore != nil,
            removeFromStore: { context in
                try DayBoardMutations.taskRepo(for: context).deleteTodo(id: item.id, soft: false)
            },
            purgesOwner: ownerKey,
            filesToRemove: ownedFiles,
            detail: .todo(detail)
        )
    }

    static func diary(
        _ item: DiaryEntry,
        attachments: [AttachmentItem],
        tags: @escaping () -> [TagItem],
        locale: Locale,
        attachmentStore: AttachmentStore? = .shared
    ) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        let ownerKey = AttachmentOwnerKey(kind: .diary, id: item.id)
        let ownedFiles = attachments.filter { $0.ownerKey == ownerKey }.map(\.id)
        let isPrivateCheck: () -> Bool = {
            item.hasProtectedContent || DiaryPrivacy.isSensitive(item.snapshot, tags: tags())
        }
        let textProvider: () -> String = {
            DiaryPrivacy.displayText(item.snapshot, tags: tags(), locale: locale)
        }
        let detail = TrashDiaryDetail(
            dayKey: item.dayKey,
            isPinned: item.isPinned,
            isPrivateProvider: isPrivateCheck,
            fullTextProvider: textProvider,
            tagsProvider: {
                guard !isPrivateCheck() else { return [] }
                return TrashTagSummary.resolve(tagIDs: item.tagIDs, from: tags())
            },
            attachmentCount: ownedFiles.count,
            createdAt: item.createdAt
        )
        return TrashRow(
            id: item.id,
            title: "",
            section: .diary,
            kindLabel: "trash.kind.diary",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreDiary(item) },
            purge: { attachmentStore.map { DayBoardMutations.purgeDiary(item, attachments: $0) } ?? false },
            canPurge: attachmentStore != nil,
            removeFromStore: { context in
                try DayBoardMutations.diaryRepo(for: context).deleteDiary(id: item.id, soft: false)
            },
            purgesOwner: ownerKey,
            titleProvider: textProvider,
            filesToRemove: ownedFiles,
            detail: .diary(detail)
        )
    }

    static func tag(_ item: TagItem) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        let detail = TrashTagDetail(
            colorToken: item.colorToken,
            isDiaryPreset: item.isDiaryPreset,
            isPrivateDiary: item.isPrivateDiary
        )
        return TrashRow(
            id: item.id,
            title: item.name,
            section: .tag,
            kindLabel: "trash.kind.tag",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreTag(item) },
            purge: { DayBoardMutations.purgeTag(item) },
            removeFromStore: { context in
                try DayBoardMutations.catalogRepo(for: context).deleteTag(id: item.id, soft: false)
            },
            detail: .tag(detail)
        )
    }

    static func attachment(
        _ item: AttachmentItem,
        ownerDeleted: Bool,
        ownerTitle: String? = nil,
        isPrivate: Bool = false,
        titleProvider: (() -> String)? = nil,
        attachmentStore: AttachmentStore? = .shared
    ) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        let effectivePrivate = isPrivate || item.privacyVaultID != nil
        let detail = TrashAttachmentDetail(
            reference: item.reference,
            isPrivate: effectivePrivate,
            ownerKind: AttachmentOwner(rawValue: item.ownerKind),
            ownerTitle: ownerTitle,
            ownerDeleted: ownerDeleted,
            createdAt: item.createdAt
        )
        return TrashRow(
            id: item.id,
            title: item.filename,
            section: .attachment,
            kindLabel: "trash.kind.attachment",
            isResident: false,
            deletedAt: deletedAt,
            restore: {
                guard !ownerDeleted else { return }
                _ = DayBoardMutations.restoreAttachment(item)
            },
            purge: {
                guard let context = item.modelContext, let attachmentStore else { return false }
                return ModelChanges.attempt(in: context) {
                    try AttachmentCleanup.purge(ids: [item.id], context: context, store: attachmentStore)
                }
            },
            canPurge: attachmentStore != nil,
            removeFromStore: { _ in
                // 文件成功删除后由 AttachmentCleanup 移除元数据，失败则留在回收站供重试。
            },
            skipIfOwnerPurged: item.ownerKey,
            canRestore: !ownerDeleted,
            titleProvider: titleProvider,
            filesToRemove: [item.id],
            detail: .attachment(detail)
        )
    }
}
