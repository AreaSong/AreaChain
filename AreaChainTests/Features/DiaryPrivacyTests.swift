import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct DiaryPrivacyTests {
    @Test func recognizesPrivateAliasesAndDeletedTagsWithoutReclassifyingOrdinaryText() {
        let tag = TagItem(name: "My PASSWORD", sortOrder: 0, deletedAt: .now)
        let entry = DiaryEntry(text: "测试私密正文", dayKey: "2026-09-11", tagIDs: tag.id.uuidString)
        #expect(DiaryPrivacy.isSensitive(entry.snapshot, tags: [tag]))
        entry.tagIDs = ""
        #expect(!DiaryPrivacy.isSensitive(entry.snapshot, tags: [tag]))
        entry.text = "#密码 测试"
        #expect(DiaryPrivacy.isSensitive(entry.snapshot, tags: []))
        entry.text = "#PASSWORD 测试"
        #expect(DiaryPrivacy.isSensitive(entry.snapshot, tags: []))
        entry.text = "关于 password 的一般说明"
        #expect(!DiaryPrivacy.isSensitive(entry.snapshot, tags: []))
    }

    @Test func maskingAlwaysWinsOverAnExistingEditor() {
        #expect(DiaryPrivacy.contentMode(isSensitive: true, isMasked: true, isEditing: true) == .masked)
        #expect(DiaryPrivacy.contentMode(isSensitive: true, isMasked: false, isEditing: true) == .editing)
        #expect(DiaryPrivacy.contentMode(isSensitive: false, isMasked: true, isEditing: false) == .text)
        #expect(!DiaryPrivacy.canReveal(isSensitive: true, isMasked: true))
    }

    @Test func confirmationUsesLivePrivacyProjectionInsteadOfKeepingCleartextCopy() throws {
        let tag = TagItem(name: "普通标签", sortOrder: 0)
        let entry = DiaryEntry(text: "private-test-value", dayKey: "2026-09-11", tagIDs: tag.id.uuidString)
        let pending = PendingTrash.diary(entry, tags: { [tag] }, locale: Locale(identifier: "en"), confirm: {})
        #expect(pending.title.isEmpty)
        #expect(pending.displayTitle == entry.text)
        tag.name = "密码"
        #expect(!pending.displayTitle.contains(entry.text))
        entry.deletedAt = .now
        let trash = try #require(TrashRow.diary(entry, attachments: [], tags: { [tag] }, locale: Locale(identifier: "en")))
        #expect(trash.title.isEmpty)
        #expect(!trash.displayTitle.contains(entry.text))
    }

    @Test func searchCanLocatePrivateNoteWithoutReturningItsBodyAsTitleOrHelp() throws {
        let tag = TagItem(name: "密码", sortOrder: 0, deletedAt: .now)
        let entry = DiaryEntry(text: "account private-test-value", dayKey: "2026-09-11", tagIDs: tag.id.uuidString)
        let hits = BoardSearch.hits(
            query: "account", todos: [], diaries: [entry.snapshot], routines: [],
            privacy: BoardSearchPrivacy(sensitiveDiaryIDs: [entry.id], placeholder: "PRIVATE")
        )
        let hit = try #require(hits.first)
        #expect(hit.id == entry.id)
        #expect(hit.title == "PRIVATE")
        #expect(!hit.title.contains("private-test-value"))
        #expect(entry.text == "account private-test-value")
    }

    @Test func typedOwnerPreventsPublicTaskFromExposingPrivateDiaryAttachment() {
        let id = UUID()
        let tag = TagItem(name: "密码", sortOrder: 0)
        let diary = DiaryEntry(id: id, text: "私密", dayKey: "2026-09-11", tagIDs: tag.id.uuidString)
        let todo = TodoItem(id: id, title: "公开任务", dayKey: "2026-09-11")
        let image = AttachmentItem(ownerKind: "diary", ownerID: id, filename: "private.png")
        #expect(!AttachmentAccess.canBrowse(image, todos: [todo], routines: [], diaries: [diary], tags: [tag]))
        #expect(Catalog.liveAttachments(for: id, in: [image], ownerKind: .todo).isEmpty)
        #expect(AttachmentAccess.ownerIsLive(AttachmentOwnerKey(kind: .diary, id: id), todos: [todo], routines: [], diaries: [diary]))
        diary.tagIDs = ""
        #expect(AttachmentAccess.canBrowse(image, todos: [todo], routines: [], diaries: [diary], tags: [tag]))
        diary.deletedAt = .now
        #expect(!AttachmentAccess.canBrowse(image, todos: [todo], routines: [], diaries: [diary], tags: [tag]))
    }

    @Test func explicitCopyStillWorksWithoutRevealingPrivateNote() {
        let entry = DiaryEntry(text: "#密码 synthetic-copy-value", dayKey: "2026-09-11")
        let pasteboard = NSPasteboard(name: .init("areachain.privacy.tests.\(UUID())"))
        defer { pasteboard.clearContents() }
        let card = DiaryNoteCard(entry: entry, activeTags: [], attachments: [], onDelete: {})
        #expect(!card.canRevealContent)
        card.copyContent(to: pasteboard)
        #expect(pasteboard.string(forType: .string) == entry.text)
        #expect(!card.canRevealContent)
    }
}
