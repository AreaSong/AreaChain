import Foundation
import SwiftData
@testable import AreaChain

/// 抽取前算法的逐字副本（只把系统依赖换成参数）：不调用新共享入口，防止新旧两个委托互相比对的伪等价。
/// 来源：InputTagResolver.resolve／merging、InputAttachmentResolver.linkIfPresent、DayBoardMutations.saveNotes、
/// addCapturedRoutine、applyManualOrder（均为 a3c81b6 时的实现）。
@MainActor enum TaskTM6LegacyRules {
    static func resolve(_ names: [String], in context: ModelContext) throws -> [UUID] {
        var tags = try context.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        var byName: [String: [TagItem]] = [:]
        byName.reserveCapacity(tags.count)
        for tag in tags {
            byName[TagSyntax.normalizedName(tag.name), default: []].append(tag)
        }
        var nextOrder = (tags.map(\.sortOrder).max() ?? -1) + 1
        return TagSyntax.uniqueNames(names).map { name in
            let key = TagSyntax.normalizedName(name)
            let matches = byName[key] ?? []
            if let existing = matches.first(where: { $0.deletedAt == nil }) ?? matches.first {
                if existing.deletedAt != nil { existing.deletedAt = nil }
                return existing.id
            }
            let tag = TagItem(name: name, sortOrder: nextOrder)
            nextOrder += 1
            context.insert(tag)
            tags.append(tag)
            byName[key, default: []].append(tag)
            return tag.id
        }
    }

    static func merging(_ names: [String], into existing: String, in context: ModelContext) throws -> String {
        var seen: Set<UUID> = []
        let ids = TagIDList.parse(existing) + (try resolve(names, in: context))
        return TagIDList.encode(ids.filter { seen.insert($0).inserted })
    }

    static func link(in text: String, ownerKind: AttachmentOwner, ownerID: UUID, context: ModelContext,
                     store: AttachmentStore, root: URL?) {
        let names = AttachmentSyntax.names(in: text)
        guard !names.isEmpty else { return }
        let allLive = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? []
        let tags = (try? context.fetch(FetchDescriptor<TagItem>())) ?? []
        let owners = (try? AttachmentAccess.ownerIndex(context: context, keys: allLive.compactMap(\.ownerKey))) ?? .empty
        let unlinked = AttachmentPoolStore.unlinkedItems(store: store, root: root)
        let storageIDs = allLive.map { $0.storageID ?? $0.id } + unlinked.map(\.id)
        let hashes = AttachmentPoolStore.contentHashes(for: storageIDs, store: store, root: root)
        let library = AttachmentLibraryProjection.build(attachments: allLive, unlinked: unlinked, owners: owners,
                                                        tags: tags, contentHashes: hashes)
        var existingStorageIDs = Set(allLive.filter { $0.ownerKind == ownerKind.rawValue && $0.ownerID == ownerID }
            .map { $0.storageID ?? $0.id })
        for name in names {
            let key = AttachmentSyntax.normalizedName(name)
            guard let match = library.first(where: { AttachmentSyntax.normalizedName($0.filename) == key }) else { continue }
            guard existingStorageIDs.insert(match.storageID).inserted else { continue }
            let item = AttachmentItem(ownerKind: ownerKind.rawValue, ownerID: ownerID, filename: match.filename)
            item.storageID = match.storageID
            context.insert(item)
            if match.isInUnlinkedPool {
                for id in match.allStorageIDs { AttachmentPoolStore.removeUnlinkedEntry(id: id, store: store, root: root) }
            }
        }
    }

    private static func update(_ notes: String, _ parsed: ParsedCapture, _ tagIDs: String) -> ParsedNoteUpdate {
        ParsedNoteUpdate(notes: notes, tagIDs: tagIDs, remindMinutes: parsed.remindMinutes,
                         isImportant: parsed.hasPriorityToken ? parsed.isImportant : nil,
                         isUrgent: parsed.hasPriorityToken ? parsed.isUrgent : nil)
    }

    static func saveNotes(_ notes: String, for todo: TodoItem, context: ModelContext, boundary: ModelChanges.Boundary,
                          attachments: TaskNotesService.Attachments, request: (Int?) -> Void) -> Bool {
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let saved = ModelChanges.perform(in: context, boundary: boundary) {
            let merged = try merging(parsed.tagNames, into: todo.tagIDs, in: context)
            try SwiftDataTaskRepository(context: context).applyParsedNotes(id: todo.id, update: update(notes, parsed, merged))
            link(in: notes, ownerKind: .todo, ownerID: todo.id, context: context, store: attachments.store, root: attachments.root)
        }
        if saved { request(parsed.remindMinutes) }
        return saved
    }

    static func saveNotes(_ notes: String, for routine: DailyRoutine, context: ModelContext, boundary: ModelChanges.Boundary,
                          attachments: TaskNotesService.Attachments, request: (Int?) -> Void) -> Bool {
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let saved = ModelChanges.perform(in: context, boundary: boundary) {
            let merged = try merging(parsed.tagNames, into: routine.tagIDs, in: context)
            try SwiftDataRoutineRepository(context: context).applyParsedNotes(id: routine.id, update: update(notes, parsed, merged))
            link(in: notes, ownerKind: .routine, ownerID: routine.id, context: context,
                 store: attachments.store, root: attachments.root)
        }
        if saved { request(parsed.remindMinutes) }
        return saved
    }

    static func addCapturedRoutine(text: String, sortOrder: Int, context: ModelContext, boundary: ModelChanges.Boundary,
                                   createdDayKey: String, attachments: TaskNotesService.Attachments,
                                   request: (Int?) -> Void) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let saved = ModelChanges.perform(in: context, boundary: boundary) {
            let ids = try resolve(parsed.tagNames, in: context)
            let routine = try SwiftDataRoutineRepository(context: context).addRoutine(CreateRoutineParams(
                title: parsed.cleanTitle, sortOrder: sortOrder, remindMinutes: parsed.remindMinutes,
                tagIDs: ids, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent, notes: parsed.notes,
                createdDayKey: createdDayKey))
            link(in: text, ownerKind: .routine, ownerID: routine.id, context: context,
                 store: attachments.store, root: attachments.root)
        }
        if saved { request(parsed.remindMinutes) }
        return saved
    }

    static func applyManualOrder(_ entries: [ManualOrderEntry], context: ModelContext, boundary: ModelChanges.Boundary) -> Bool {
        let changed = entries
        return ModelChanges.perform(in: context, boundary: boundary) {
            let todos = try context.fetch(FetchDescriptor<TodoItem>())
            let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
            let todoMap = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
            let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
            for entry in changed {
                if let todo = todoMap[entry.id] {
                    todo.sortOrder = entry.sortOrder
                } else if let routine = routineMap[entry.id] {
                    routine.sortOrder = entry.sortOrder
                }
            }
        }
    }
}
