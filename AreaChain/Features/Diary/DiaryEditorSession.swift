import AppKit
import Foundation
import Observation
import SwiftData

/// 解密正文仅属于编辑会话；锁定时封存草稿，不回填可自动保存的模型属性。
@Observable @MainActor
final class DiaryEditorSession {
    struct PendingAttachment: Identifiable, Equatable, Codable {
        var id = UUID()
        var filename: String
        var data: Data
        var reference: AttachmentRef { AttachmentRef(id: id, filename: filename) }
    }

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
    private(set) var pendingAttachments: [PendingAttachment] = []
    private(set) var removedAttachmentIDs: Set<UUID> = []
    var title: String {
        didSet { if needsUnlock { vault.touch() } }
    }
    var text: String {
        didSet { if needsUnlock { vault.touch() } }
    }
    var isWindowPinned = false

    private var baselineTitle: String
    private var baseline: String
    private var baselineTags: String
    private var initialTagIDs: Set<UUID>
    private var privacyTags: [TagItem] = []
    private var privacyUnavailable = false
    private let attachmentStore: any AttachmentStorageProtocol
    private let commit: (ModelContext) throws -> Void
    private var sealedDraft: SealedDiaryDraft?
    private var sealedAttachments: Data?
    @ObservationIgnored private var privacyObservers: [NSObjectProtocol] = []

    init(source: Source, context: ModelContext, vault: PrivacyVault? = nil,
         attachmentStore: any AttachmentStorageProtocol = AttachmentStore.shared,
         commit: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.vault = vault ?? .shared
        self.attachmentStore = attachmentStore
        self.commit = commit
        switch source {
        case .entry(let entry):
            record = entry
            entryID = entry.id
            sourceDraftID = nil
            dayKey = entry.dayKey
            let initialText = (try? DiaryContent.read(entry, vault: self.vault)) ?? ""
            let parts = Self.split(storedText: initialText, hasExplicitTitle: entry.hasExplicitTitle)
            title = parts.title
            text = parts.body
            baselineTitle = parts.title
            baseline = parts.body
            baselineTags = entry.tagIDs
            initialTagIDs = []
        case .draft(let draft, let key):
            sourceDraftID = draft.id
            dayKey = key
            title = ""
            text = draft.text
            sealedDraft = draft.sealed
            baselineTitle = ""
            baseline = ""
            baselineTags = TagIDList.encode(Array(draft.selectedTagIDs))
            initialTagIDs = draft.selectedTagIDs
        }
        observePrivacy()
        refresh()
    }

    deinit { privacyObservers.forEach { NotificationCenter.default.removeObserver($0) } }

    var composedText: String {
        Self.compose(title: title, body: text)
    }

    static func compose(title: String, body: String) -> String {
        let cleanTitle = title.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty { return body }
        if cleanBody.isEmpty { return cleanTitle }
        return cleanTitle + "\n" + body
    }

    static func split(storedText: String, hasExplicitTitle: Bool) -> (title: String, body: String) {
        guard hasExplicitTitle else { return ("", storedText) }
        guard let newline = storedText.firstIndex(of: "\n") else { return (storedText, "") }
        let firstLine = String(storedText[..<newline])
        let rest = String(storedText[storedText.index(after: newline)...])
        return (firstLine, rest)
    }

    var hasUnsavedChanges: Bool {
        (sealedDraft?.isDirty ?? (title != baselineTitle || text != baseline))
            || !pendingAttachments.isEmpty || !removedAttachmentIDs.isEmpty || sealedAttachments != nil
    }
    var canSave: Bool {
        hasUnsavedChanges
            && (!composedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !pendingAttachments.isEmpty
                || !removedAttachmentIDs.isEmpty)
            && issue != .conflict && issue != .missing
    }
    var statusKey: String {
        issue?.rawValue ?? (hasUnsavedChanges ? "diary.window.unsaved" : "diary.window.saved")
    }
    var showsWindowUnsavedBadge: Bool {
        issue != nil || hasUnsavedChanges || entryID == nil
    }

    func windowHeading(locale: Locale) -> String {
        guard canRevealContent else {
            return L10n.string("diary.private.title", locale: locale)
        }
        let cleanTitle = title.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            return cleanTitle
        }
        let cleanBody = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanBody.isEmpty {
            return cleanBody
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? cleanBody
        }
        return L10n.string(entryID == nil ? "diary.window.new" : "tab.diary", locale: locale)
    }

    func plainWindowTitle(locale: Locale) -> String {
        let heading = windowHeading(locale: locale)
        if showsWindowUnsavedBadge {
            let status = L10n.string("diary.window.unsaved", locale: locale)
            return "\(heading) · \(status)"
        }
        return heading
    }

    var isSensitive: Bool {
        let draft = DiarySnapshot(id: entryID ?? id, text: composedText, dayKey: dayKey, createdAt: .now,
                                  tagIDs: record?.tagIDs ?? baselineTags)
        return needsUnlock || DiaryPrivacy.isSensitive(draft, tags: privacyTags)
            || record.map { DiaryPrivacy.isSensitive($0.snapshot, tags: privacyTags) } == true
    }
    var needsUnlock: Bool {
        if record?.hasProtectedContent == true || sealedDraft != nil { return true }
        let attached = Set(TagIDList.parse(record?.tagIDs ?? baselineTags))
        return DiaryContent.requiresProtection(text: composedText, tagIDs: attached, tags: privacyTags)
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

    @discardableResult
    func stageAttachment(data: Data, filename: String) -> Bool {
        guard !privacyUnavailable, issue != .missing,
              !needsUnlock || vault.isUnlocked,
              NSImage(data: data) != nil else { return false }
        if !pendingAttachments.contains(where: { $0.data == data }) {
            let existingRows = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments)))?.map(\.filename) ?? []
            let poolNames = (attachmentStore as? AttachmentStore).map { AttachmentPoolStore.unlinkedItems(store: $0).map(\.filename) } ?? []
            let knownNames = existingRows + poolNames + pendingAttachments.map(\.filename)
            let resolvedName = AttachmentSyntax.uniqueFilename(base: filename, existing: knownNames)
            pendingAttachments.append(PendingAttachment(filename: resolvedName, data: data))
        }
        if needsUnlock { vault.touch() }
        return true
    }

    @discardableResult
    func pasteAttachment(from pasteboard: NSPasteboard = .general) -> Bool {
        guard canRevealContent,
              let image = ImageBytes.pasteboardImage(pasteboard),
              let data = ImageBytes.png(from: image) else {
            NSSound.beep()
            return false
        }
        return stageAttachment(data: data, filename: "paste.png")
    }

    func removeAttachment(id: UUID) {
        guard canRevealContent else { return }
        if let index = pendingAttachments.firstIndex(where: { $0.id == id }) {
            pendingAttachments.remove(at: index)
        } else {
            removedAttachmentIDs.insert(id)
        }
        if needsUnlock { vault.touch() }
    }

    /// 没有本地编辑时跟随外部修改；有草稿时保留原文，要求显式处理冲突。
    func refresh() {
        do {
            privacyTags = try context.fetch(FetchDescriptor<TagItem>())
            privacyUnavailable = false
            if let sealedDraft, vault.isUnlocked {
                let draft = try sealedDraft.open(vault: vault)
                if let sealedAttachments, let vaultID = vault.configuration?.vaultID {
                    let raw = try vault.keys.open(sealedAttachments, vaultID: vaultID, context: "draft-attachments:\(id.uuidString)")
                    pendingAttachments = try JSONDecoder().decode([PendingAttachment].self, from: raw)
                    self.sealedAttachments = nil
                }
                title = draft.title
                text = draft.text
                baselineTitle = draft.baselineTitle
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
            let latestParts = Self.split(storedText: latestText, hasExplicitTitle: latest.hasExplicitTitle)
            guard latestParts.title != baselineTitle || latestParts.body != baseline else {
                if issue == .missing || issue == .conflict { issue = nil }
                return
            }
            mask()
            if hasUnsavedChanges { issue = .conflict }
            else {
                title = latestParts.title
                text = latestParts.body
                baselineTitle = latestParts.title
                baseline = latestParts.body
                issue = nil
            }
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
            let latestText = try DiaryContent.read(latest, vault: vault)
            let parts = Self.split(storedText: latestText, hasExplicitTitle: latest.hasExplicitTitle)
            title = parts.title
            text = parts.body
            baselineTitle = parts.title
            baseline = parts.body
            sealedDraft = nil
            sealedAttachments = nil
            pendingAttachments.removeAll()
            removedAttachmentIDs.removeAll()
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
        let cleanTitle = title.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExplicit = !cleanTitle.isEmpty
        let trimmed = Self.compose(title: cleanTitle, body: text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let next = trimmed.isEmpty
            ? L10n.string("capture.image", locale: AppPreferences.shared.resolvedLocale)
            : trimmed
        var writtenIDs: [UUID] = []
        do {
            let saved = try ModelChanges.transaction(in: context, save: commit) {
                // 保存里的 @附件关联与暂存附件写入同一存储；默认会话仍是共享目录，与原先一致。
                let repository = SwiftDataDiaryRepository(context: context, vault: vault,
                    attachmentStore: (attachmentStore as? AttachmentStore) ?? .shared)
                let entry: DiaryEntry
                if let entryID, let record {
                    try repository.editDiary(id: entryID, text: next)
                    record.hasExplicitTitle = hasExplicit
                    entry = record
                } else {
                    entry = try repository.addDiary(text: next, dayKey: dayKey, tagIDs: initialTagIDs)
                    entry.hasExplicitTitle = hasExplicit
                }
                if !removedAttachmentIDs.isEmpty {
                    let allAttachments = try context.fetch(
                        FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments)
                    )
                    for att in allAttachments where att.ownerID == entry.id && removedAttachmentIDs.contains(att.id) {
                        att.deletedAt = .now
                    }
                }
                for item in pendingAttachments {
                    writtenIDs.append(item.id)
                    if let concreteStore = attachmentStore as? AttachmentStore {
                        _ = try AttachmentPoolStore.saveOrLink(
                            data: item.data, filename: item.filename, ownerKind: .diary,
                            ownerID: entry.id, context: context, store: concreteStore, id: item.id
                        )
                    } else {
                        _ = try attachmentStore.save(
                            data: item.data, filename: item.filename, ownerKind: .diary,
                            ownerID: entry.id, context: context, id: item.id
                        )
                    }
                }
                return entry
            }
            record = saved
            entryID = saved.id
            let savedText = try DiaryContent.read(saved, vault: vault)
            let parts = Self.split(storedText: savedText, hasExplicitTitle: saved.hasExplicitTitle)
            title = parts.title
            text = parts.body
            baselineTitle = parts.title
            baseline = parts.body
            baselineTags = saved.tagIDs
            initialTagIDs = []
            pendingAttachments.removeAll()
            removedAttachmentIDs.removeAll()
            sealedAttachments = nil
            issue = nil
            refresh()
            mask()
            return true
        } catch {
            for id in writtenIDs { attachmentStore.removeFile(id: id) }
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
            sealedDraft = try SealedDiaryDraft.seal(
                text: text, baseline: baseline, title: title, baselineTitle: baselineTitle,
                id: id, vault: vault
            )
            if !pendingAttachments.isEmpty, let vaultID = vault.configuration?.vaultID {
                let raw = try JSONEncoder().encode(pendingAttachments)
                sealedAttachments = try vault.keys.seal(raw, vaultID: vaultID, context: "draft-attachments:\(id.uuidString)")
            }
            title = ""
            text = ""
            baselineTitle = ""
            baseline = ""
            pendingAttachments.removeAll()
        } catch {
            // 保留会话供恢复，不把失败草稿写入磁盘或显示在锁定界面。
            privacyUnavailable = true
            issue = .failed
        }
    }
}
