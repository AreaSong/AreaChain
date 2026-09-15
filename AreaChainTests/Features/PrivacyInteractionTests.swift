import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacyInteractionTests {
    @Test func filteredOutCardKeepsItsSealedUnsavedSession() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "FILTER_PRIVATE_SENTINEL", dayKey: "2026-09-15", tagIDs: [tag.id])
        let drafts = DiaryCardDrafts()
        let editor = drafts.begin(note, context: f.context, vault: f.vault)
        editor.text += " 尚未保存"
        let query = BoardSearch.parseQuery("FILTER_PRIVATE_SENTINEL")
        #expect(BoardSearch.matchesDiary(DiaryContent.snapshot(note, vault: f.vault), query: query, tagMap: [:]))
        f.vault.lock()
        #expect(!BoardSearch.matchesDiary(DiaryContent.snapshot(note, vault: f.vault), query: query, tagMap: [:]))
        #expect(drafts.editor(for: note.id) === editor)
        #expect(editor.text.isEmpty && editor.hasUnsavedChanges)
        try await f.vault.unlockWithPassword("fixture-master-password")
        #expect(!editor.canRevealContent)
        let resumed = drafts.begin(note, context: f.context, vault: f.vault)
        #expect(resumed === editor && resumed.text == "FILTER_PRIVATE_SENTINEL 尚未保存")
        #expect(resumed.save())
        drafts.discard(note.id)
        #expect(drafts.editor(for: note.id) == nil)
        #expect(try DiaryContent.read(note, vault: f.vault) == "FILTER_PRIVATE_SENTINEL 尚未保存")
    }

    @Test func privateImageSelectionSurvivesMaskingButRejectsADeletedOwner() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "测试私密图片", dayKey: "2026-09-15", tagIDs: [tag.id])
        let session = DiaryEditorSession(source: .entry(note), context: f.context, vault: f.vault)
        session.reveal()
        let url = f.root.appending(path: "selected-source.png")
        let bytes = try png()
        try bytes.write(to: url)
        var completeSelection: (@MainActor (URL) -> Void)?
        AttachmentPicker.pickDiaryImage(note, context: f.context, vault: f.vault, store: f.files,
                                        selectURL: { completeSelection = $0 })
        session.mask()
        #expect(!session.canRevealContent && f.vault.isUnlocked)
        let acceptFirst = try #require(completeSelection)
        acceptFirst(url)
        let image = try #require(try f.context.fetch(FetchDescriptor<AttachmentItem>()).first)
        #expect(image.privacyVaultID == f.vault.configuration?.vaultID)
        #expect(try f.files.read(reference: image.reference) == bytes)
        AttachmentPicker.pickDiaryImage(note, context: f.context, vault: f.vault, store: f.files,
                                        selectURL: { completeSelection = $0 })
        try f.repository.deleteDiary(id: note.id, soft: true)
        let acceptDeleted = try #require(completeSelection)
        acceptDeleted(url)
        #expect(try f.context.fetchCount(FetchDescriptor<AttachmentItem>()) == 1)
    }

    @Test func staleTagActionsCannotChangeDeletedNotesOrDeletedTags() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "原文", dayKey: "2026-09-15", tagIDs: [])
        tag.deletedAt = .now
        try f.context.save()
        #expect(throws: PrivacyError.staleOperation) { try f.repository.toggleTag(id: note.id, tagID: tag.id) }
        #expect(note.tagIDs.isEmpty && !note.hasProtectedContent)
        tag.deletedAt = nil
        try f.repository.deleteDiary(id: note.id, soft: true)
        #expect(throws: PrivacyError.staleOperation) { try f.repository.toggleTag(id: note.id, tagID: tag.id) }
        #expect(throws: PrivacyError.staleOperation) { try f.repository.setTags(id: note.id, tagIDs: [tag.id]) }
        var executed = false
        PrivacyAccess.withDiary(note, vault: f.vault) { _ in executed = true }
        #expect(!executed && note.tagIDs.isEmpty && !note.hasProtectedContent)
    }

    private func png() throws -> Data {
        let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32))
        return try #require(image.representation(using: .png, properties: [:]))
    }
}
