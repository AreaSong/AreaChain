import Foundation
import Observation
import SwiftData

/// 小窗只保存一份编辑草稿；落盘仍走原有仓储事务，不改变手记 schema 或标签解析规则。
@Observable @MainActor
final class DiaryEditorSession {
    enum Source {
        case entry(DiaryEntry)
        case draft(DiaryComposerDraft, dayKey: String)
    }

    enum Issue: String {
        case failed = "diary.window.save.failed"
        case conflict = "diary.window.save.conflict"
        case missing = "diary.window.save.missing"
    }

    let id = UUID()
    let context: ModelContext
    let sourceDraftID: UUID?
    let dayKey: String
    private(set) var entryID: UUID?
    private(set) var record: DiaryEntry?
    private(set) var issue: Issue?
    private(set) var isMasked = true
    var text: String
    var isWindowPinned = false

    private var baseline: String
    private var baselineTags: String
    private var initialTagIDs: Set<UUID>
    private var privacyTags: [TagItem] = []
    private var privacyUnavailable = false
    private let commit: (ModelContext) throws -> Void

    init(source: Source, context: ModelContext, commit: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.commit = commit
        switch source {
        case .entry(let entry):
            record = entry
            entryID = entry.id
            sourceDraftID = nil
            dayKey = entry.dayKey
            text = entry.text
            baseline = entry.text
            baselineTags = entry.tagIDs
            initialTagIDs = []
        case .draft(let draft, let key):
            sourceDraftID = draft.id
            dayKey = key
            text = draft.text
            baseline = ""
            baselineTags = TagIDList.encode(Array(draft.selectedTagIDs))
            initialTagIDs = draft.selectedTagIDs
        }
        refresh()
    }

    var hasUnsavedChanges: Bool { text != baseline }
    var canSave: Bool {
        hasUnsavedChanges && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && issue != .conflict && issue != .missing
    }
    var statusKey: String {
        issue?.rawValue ?? (hasUnsavedChanges ? "diary.window.unsaved" : "diary.window.saved")
    }
    var isSensitive: Bool {
        let draft = DiarySnapshot(id: entryID ?? id, text: text, dayKey: dayKey, createdAt: .now,
                                  tagIDs: record?.tagIDs ?? baselineTags)
        return DiaryPrivacy.isSensitive(draft, tags: privacyTags)
            || record.map { DiaryPrivacy.isSensitive($0.snapshot, tags: privacyTags) } == true
    }
    var canRevealContent: Bool {
        !privacyUnavailable && issue != .missing
            && DiaryPrivacy.canReveal(isSensitive: isSensitive, isMasked: isMasked)
    }

    func mask() { isMasked = true }
    func reveal() { isMasked = false }

    /// 没有本地编辑时跟随外部修改；有草稿时保留原文，要求显式处理冲突。
    func refresh() {
        do {
            privacyTags = try context.fetch(FetchDescriptor<TagItem>())
            privacyUnavailable = false
            guard let entryID else { return }
            guard let latest = try SwiftDataDiaryRepository(context: context).fetchDiary(id: entryID),
                  latest.deletedAt == nil else {
                issue = .missing
                record = nil
                mask()
                return
            }
            record = latest
            if latest.tagIDs != baselineTags { mask(); baselineTags = latest.tagIDs }
            guard latest.text != baseline else {
                if issue == .missing || issue == .conflict { issue = nil }
                return
            }
            mask()
            if hasUnsavedChanges { issue = .conflict }
            else { text = latest.text; baseline = latest.text; issue = nil }
        } catch {
            issue = .failed
            privacyUnavailable = true
            mask()
        }
    }

    /// 调用方必须先确认舍弃草稿；不提供静默覆盖其他窗口修改的分支。
    func reloadLatest() {
        guard let entryID else { return }
        do {
            guard let latest = try SwiftDataDiaryRepository(context: context).fetchDiary(id: entryID),
                  latest.deletedAt == nil else { issue = .missing; return }
            record = latest
            text = latest.text
            baseline = latest.text
            baselineTags = latest.tagIDs
            issue = nil
            mask()
        } catch { issue = .failed }
    }

    @discardableResult
    func save() -> Bool {
        refresh()
        guard canSave else { return !hasUnsavedChanges && issue == nil }
        let next = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let saved = try ModelChanges.transaction(in: context, save: commit) {
                let repository = SwiftDataDiaryRepository(context: context)
                if let entryID, let record {
                    try repository.editDiary(id: entryID, text: next)
                    return record
                }
                return try repository.addDiary(text: next, dayKey: dayKey, tagIDs: initialTagIDs)
            }
            record = saved
            entryID = saved.id
            text = saved.text
            baseline = saved.text
            baselineTags = saved.tagIDs
            initialTagIDs = []
            issue = nil
            refresh()
            mask()
            return true
        } catch {
            issue = .failed
            MutationFeedback.shared.reportFailure(error)
            return false
        }
    }
}
