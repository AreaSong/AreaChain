import Foundation
import SwiftData

struct CatalogChoice: Identifiable, Equatable {
    var id: UUID
    var name: String
}

struct TaskClassifyContext {
    var isImportant: Bool
    var isUrgent: Bool
    var projectID: UUID?
    var tagIDs: String
    var projects: [CatalogChoice]
    var tags: [CatalogChoice]
    var sourceLabel: String?
    var onProject: (UUID?) -> Void
    var onToggleTag: (UUID) -> Void
    var onImportant: (Bool) -> Void
    var onUrgent: (Bool) -> Void
}

struct TaskAttachmentContext {
    var items: [AttachmentRef]
    var onPickFile: () -> Void
    var onPaste: () -> Void
    var onCaptureScreen: (() -> Void)? = nil
}

@MainActor
enum CatalogChoices {
    static func projects(_ items: [ProjectItem]) -> [CatalogChoice] {
        ProjectTree.outline(items).map {
            CatalogChoice(id: $0.id, name: ProjectTree.pathLabel($0.id, in: items))
        }
    }

    static func tags(_ items: [TagItem]) -> [CatalogChoice] {
        Catalog.liveTags(items).map { CatalogChoice(id: $0.id, name: $0.name) }
    }

    static func attachments(_ ownerID: UUID, in items: [AttachmentItem]) -> [AttachmentRef] {
        Catalog.liveAttachments(for: ownerID, in: items).map {
            AttachmentRef(id: $0.id, filename: $0.filename)
        }
    }

    static func classify(
        for todo: TodoItem,
        projects: [ProjectItem],
        tags: [TagItem]
    ) -> TaskClassifyContext {
        TaskClassifyContext(
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent,
            projectID: todo.projectID,
            tagIDs: todo.tagIDs,
            projects: Self.projects(projects),
            tags: Self.tags(tags),
            sourceLabel: todo.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: todo.sourceBundleID),
            onProject: { id in DayBoardMutations.persist { todo.projectID = id } },
            onToggleTag: { id in DayBoardMutations.persist { todo.tagIDs = TagIDList.toggling(todo.tagIDs, id) } },
            onImportant: { value in DayBoardMutations.persist { todo.isImportant = value } },
            onUrgent: { value in DayBoardMutations.persist { todo.isUrgent = value } }
        )
    }

    static func attachments(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        items: [AttachmentItem],
        context: ModelContext
    ) -> TaskAttachmentContext {
        TaskAttachmentContext(
            items: attachments(ownerID, in: items),
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
