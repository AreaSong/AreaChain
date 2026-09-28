import Foundation
import SwiftData

@MainActor
enum CatalogChoices {
    static func tags(_ items: [TagItem], attachedIDs: String = "") -> [CatalogChoice] {
        tags(liveTags: Catalog.liveTags(items), attachedIDs: attachedIDs)
    }

    static func tags(liveTags: [TagItem], attachedIDs: String = "") -> [CatalogChoice] {
        Catalog.taskPickerTags(liveTags: liveTags, attachedIDs: attachedIDs).map {
            CatalogChoice(id: $0.id, name: $0.name)
        }
    }

    static func attachments(_ ownerID: UUID, in items: [AttachmentItem], ownerKind: AttachmentOwner? = nil) -> [AttachmentRef] {
        CatalogAttachmentIndex(items).live(ownerID: ownerID, ownerKind: ownerKind).map(\.reference)
    }

    static func attachments(
        ownerID: UUID,
        in index: CatalogAttachmentIndex,
        ownerKind: AttachmentOwner? = nil
    ) -> [AttachmentRef] {
        index.live(ownerID: ownerID, ownerKind: ownerKind).map(\.reference)
    }

    static func classify(
        for routine: DailyRoutine,
        tags: [TagItem]
    ) -> TaskClassifyContext {
        classify(for: routine, liveTags: Catalog.liveTags(tags))
    }

    static func classify(
        for routine: DailyRoutine,
        liveTags: [TagItem]
    ) -> TaskClassifyContext {
        let priority = TaskPriorityFlags(
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent
        )
        let catalog = TaskCatalogBinding(
            tagIDs: routine.tagIDs,
            tags: Self.tags(liveTags: liveTags, attachedIDs: routine.tagIDs),
            sourceLabel: routine.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: routine.sourceBundleID)
        )
        let actions = TaskClassifyActions(
            onToggleTag: { DayBoardMutations.toggleTag(for: routine, tagID: $0) },
            onImportant: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: value, urgent: routine.isUrgent), to: routine)
            },
            onUrgent: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: routine.isImportant, urgent: value), to: routine)
            }
        )
        return TaskClassifyContext(priority: priority, catalog: catalog, actions: actions)
    }

    static func classify(
        for todo: TodoItem,
        tags: [TagItem]
    ) -> TaskClassifyContext {
        classify(for: todo, liveTags: Catalog.liveTags(tags))
    }

    static func classify(
        for todo: TodoItem,
        liveTags: [TagItem]
    ) -> TaskClassifyContext {
        let priority = TaskPriorityFlags(
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent
        )
        let catalog = TaskCatalogBinding(
            tagIDs: todo.tagIDs,
            tags: Self.tags(liveTags: liveTags, attachedIDs: todo.tagIDs),
            sourceLabel: todo.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: todo.sourceBundleID)
        )
        let actions = TaskClassifyActions(
            onToggleTag: { DayBoardMutations.toggleTag(for: todo, tagID: $0) },
            onImportant: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: value, urgent: todo.isUrgent), to: todo)
            },
            onUrgent: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: todo.isImportant, urgent: value), to: todo)
            }
        )
        return TaskClassifyContext(priority: priority, catalog: catalog, actions: actions)
    }

    static func attachments(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        items: [AttachmentItem],
        context: ModelContext
    ) -> TaskAttachmentContext {
        attachments(
            ownerKind: ownerKind,
            ownerID: ownerID,
            index: CatalogAttachmentIndex(items),
            context: context
        )
    }

    static func attachments(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        index: CatalogAttachmentIndex,
        context: ModelContext
    ) -> TaskAttachmentContext {
        TaskAttachmentContext(
            items: attachments(ownerID: ownerID, in: index, ownerKind: ownerKind),
            onPickFile: {
                AttachmentActions.pickImage(ownerKind: ownerKind, ownerID: ownerID, context: context)
            },
            onPaste: {
                _ = AttachmentActions.pasteImage(ownerKind: ownerKind, ownerID: ownerID, context: context)
            },
            onCaptureScreen: {
                AttachmentActions.captureScreen(ownerKind: ownerKind, ownerID: ownerID, context: context)
            }
        )
    }
}

/// 任务行目录与持久化上下文依赖（解耦各调用方重复传递 tags/attachments/modelContext）
struct TaskCatalogContext {
    var tags: [TagItem]
    var attachments: [AttachmentItem]
    var context: ModelContext
    var liveTags: [TagItem]
    var attachmentIndex: CatalogAttachmentIndex

    init(
        tags: [TagItem],
        attachments: [AttachmentItem],
        context: ModelContext
    ) {
        self.tags = tags
        self.attachments = attachments
        self.context = context
        self.liveTags = Catalog.liveTags(tags)
        self.attachmentIndex = CatalogAttachmentIndex(attachments)
    }

    @MainActor
    func classify(for routine: DailyRoutine) -> TaskClassifyContext {
        CatalogChoices.classify(for: routine, liveTags: liveTags)
    }

    @MainActor
    func classify(for todo: TodoItem) -> TaskClassifyContext {
        CatalogChoices.classify(for: todo, liveTags: liveTags)
    }

    @MainActor
    func attachments(ownerKind: AttachmentOwner, ownerID: UUID) -> TaskAttachmentContext {
        CatalogChoices.attachments(
            ownerKind: ownerKind,
            ownerID: ownerID,
            index: attachmentIndex,
            context: context
        )
    }
}
