import Foundation
import Observation
import SwiftData

/// 解密正文仅属于编辑会话；锁定时封存草稿，不回填可自动保存的模型属性。
@Observable @MainActor
final class DiaryEditorSession {
    enum Source {
        case entry(DiaryEntry)
        case draft(BoardComposerDraft, dayKey: String)
    }

    enum Issue: String {
        case failed = "diary.window.save.failed"
        case conflict = "diary.window.save.conflict"
        case missing = "diary.window.save.missing"
        case locked = "privacy.error.locked"
    }

    let id = UUID()
    let context: ModelContext
    let vault: PrivacyVault
    let sourceDraftID: UUID?
    let dayKey: String
    private(set) var entryID: UUID?
    private(set) var record: DiaryEntry?
    private(set) var issue: Issue?
    private(set) var isMasked = true
    var text: String {
        didSet { if needsUnlock { vault.touch() } }
    }
    var isWindowPinned = false

    private var baseline: String
    private var baselineTags: String
    private var initialTagIDs: Set<UUID>
    private var privacyTags: [TagItem] = []
    private var privacyUnavailable = false
    private let commit: (ModelContext) throws -> Void
    private var sealedDraft: SealedDiaryDraft?
    @ObservationIgnored private var privacyObservers: [NSObjectProtocol] = []

    init(source: Source, context: ModelContext, vault: PrivacyVault? = nil,
         commit: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.vault = vault ?? .shared
        self.commit = commit
        switch source {
        case .entry(let entry):
            record = entry
            entryID = entry.id
            sourceDraftID = nil
            dayKey = entry.dayKey
            let initialText = (try? DiaryContent.read(entry, vault: self.vault)) ?? ""
            text = initialText
            baseline = initialText
            baselineTags = entry.tagIDs
            initialTagIDs = []
        case .draft(let draft, let key):
            sourceDraftID = draft.id
            dayKey = key
            text = draft.text
            sealedDraft = draft.sealed
            baseline = ""
            baselineTags = TagIDList.encode(Array(draft.selectedTagIDs))
            initialTagIDs = draft.selectedTagIDs
        }
        observePrivacy()
        refresh()
    }

    deinit { privacyObservers.forEach { NotificationCenter.default.removeObserver($0) } }

    var hasUnsavedChanges: Bool { sealedDraft?.isDirty ?? (text != baseline) }
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
        return needsUnlock || DiaryPrivacy.isSensitive(draft, tags: privacyTags)
            || record.map { DiaryPrivacy.isSensitive($0.snapshot, tags: privacyTags) } == true
    }
    var needsUnlock: Bool {
        if record?.hasProtectedContent == true || sealedDraft != nil { return true }
        let attached = Set(TagIDList.parse(record?.tagIDs ?? baselineTags))
        return DiaryContent.requiresProtection(text: text, tagIDs: attached, tags: privacyTags)
    }
    var canRevealContent: Bool {
        !privacyUnavailable && issue != .missing
            && (!needsUnlock || vault.isUnlocked)
            && DiaryPrivacy.canReveal(isSensitive: isSensitive, isMasked: isMasked)
    }

    func mask() { isMasked = true }
    func reveal() {
        guard !needsUnlock || vault.isUnlocked else { issue = .locked; return }
        refresh()
        guard !privacyUnavailable, issue != .missing else { return }
        if issue == .locked { issue = nil }
        isMasked = false
        vault.touch()
    }

    /// 没有本地编辑时跟随外部修改；有草稿时保留原文，要求显式处理冲突。
    func refresh() {
        do {
            privacyTags = try context.fetch(FetchDescriptor<TagItem>())
            privacyUnavailable = false
            if let sealedDraft, vault.isUnlocked {
                let draft = try sealedDraft.open(vault: vault)
                text = draft.text
                baseline = draft.baseline
                self.sealedDraft = nil
            }
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
            if latest.hasProtectedContent && !vault.isUnlocked { mask(); return }
            let latestText = try DiaryContent.read(latest, vault: vault)
            guard latestText != baseline else {
                if issue == .missing || issue == .conflict { issue = nil }
                return
            }
            mask()
            if hasUnsavedChanges { issue = .conflict }
            else { text = latestText; baseline = latestText; issue = nil }
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
            text = try DiaryContent.read(latest, vault: vault)
            baseline = text
            sealedDraft = nil
            baselineTags = latest.tagIDs
            issue = nil
            mask()
        } catch { issue = .failed }
    }

    @discardableResult
    func save() -> Bool {
        refresh()
        guard !needsUnlock || vault.isUnlocked else { issue = .locked; return false }
        guard canSave else { return !hasUnsavedChanges && issue == nil }
        let next = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let saved = try ModelChanges.transaction(in: context, save: commit) {
                let repository = SwiftDataDiaryRepository(context: context, vault: vault)
                if let entryID, let record {
                    try repository.editDiary(id: entryID, text: next)
                    return record
                }
                return try repository.addDiary(text: next, dayKey: dayKey, tagIDs: initialTagIDs)
            }
            record = saved
            entryID = saved.id
            text = try DiaryContent.read(saved, vault: vault)
            baseline = text
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

    private func observePrivacy() {
        let center = NotificationCenter.default
        privacyObservers.append(center.addObserver(forName: .privacyWillLock, object: vault, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sealForLock() }
        })
        privacyObservers.append(center.addObserver(forName: .privacyDidChange, object: vault, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        privacyObservers.append(center.addObserver(forName: .privacyMask, object: vault, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mask() }
        })
    }

    private func sealForLock() {
        mask()
        guard needsUnlock, sealedDraft == nil, vault.isUnlocked else { return }
        do {
            sealedDraft = try SealedDiaryDraft.seal(text: text, baseline: baseline, id: id, vault: vault)
            text = ""
            baseline = ""
        } catch {
            // 保留会话供恢复，不把失败草稿写入磁盘或显示在锁定界面。
            privacyUnavailable = true
            issue = .failed
        }
    }
}
