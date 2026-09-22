import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryEditorSessionTests {
    @Test func draftStaysInMemoryUntilSavedAndSubsequentSavesKeepIdentity() throws {
        let container = try fixture()
        let context = container.mainContext
        let draft = BoardComposerDraft(text: "长文草稿 #工作")
        let session = DiaryEditorSession(source: .draft(draft, dayKey: "2026-09-13"), context: context)
        #expect(session.entryID == nil && session.hasUnsavedChanges)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(session.save())
        let id = try #require(session.entryID)
        #expect(!session.hasUnsavedChanges)
        session.text += "\n继续写下一行"
        #expect(session.save())
        #expect(session.entryID == id)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        let saved = try #require(context.fetch(FetchDescriptor<DiaryEntry>()).first)
        #expect(saved.text == session.text && saved.dayKey == "2026-09-13")
        let tag = try #require(context.fetch(FetchDescriptor<TagItem>()).first { $0.name == "工作" })
        #expect(TagIDList.contains(saved.tagIDs, tag.id))
    }

    @Test func failedSaveRollsBackNewTagsAndKeepsDraftForRetry() throws {
        let container = try fixture()
        let context = container.mainContext
        var rejectsSave = true
        let session = DiaryEditorSession(source: .draft(BoardComposerDraft(text: "不能丢失 #新标签"), dayKey: "2026-09-13"),
                                         context: context, commit: { ctx in
            if rejectsSave { throw CocoaError(.fileWriteNoPermission) }
            try ctx.save()
        })
        #expect(!session.save())
        #expect(session.text == "不能丢失 #新标签" && session.hasUnsavedChanges)
        #expect(session.entryID == nil && session.issue == .failed)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        rejectsSave = false
        #expect(session.save())
        #expect(session.issue == nil && !session.hasUnsavedChanges)
    }

    @Test func failedExistingSaveKeepsPersistedTextAndDraftSeparate() throws {
        let container = try fixture()
        let entry = try note(in: container)
        let session = DiaryEditorSession(source: .entry(entry), context: container.mainContext,
                                         commit: { _ in throw CocoaError(.fileWriteNoPermission) })
        session.text = "尚未落盘的修改"
        #expect(!session.save())
        #expect(entry.text == "原始记录")
        #expect(session.text == "尚未落盘的修改")
        #expect(session.hasUnsavedChanges)
    }

    @Test func externalEditsRefreshCleanSessionButNeverOverwriteDirtyDraft() throws {
        let container = try fixture()
        let entry = try note(in: container)
        let session = DiaryEditorSession(source: .entry(entry), context: container.mainContext)
        let repository = SwiftDataDiaryRepository(context: container.mainContext)
        try repository.editDiary(id: entry.id, text: "工作台第一次修改")
        session.refresh()
        #expect(session.text == "工作台第一次修改" && !session.hasUnsavedChanges)
        session.text = "小窗里的未保存版本"
        try repository.editDiary(id: entry.id, text: "工作台第二次修改")
        #expect(!session.save())
        #expect(session.issue == .conflict)
        #expect(session.text == "小窗里的未保存版本")
        #expect(entry.text == "工作台第二次修改")
        session.reloadLatest()
        #expect(session.issue == nil && !session.hasUnsavedChanges)
        #expect(session.text == entry.text)
        session.text = "核对后继续修改"
        #expect(session.save())
    }

    @Test(arguments: [false, true])
    func deletionCannotBeUndoneAccidentallyBySavingAnOldWindow(_ permanent: Bool) throws {
        let container = try fixture()
        let entry = try note(in: container)
        let session = DiaryEditorSession(source: .entry(entry), context: container.mainContext)
        session.text = "删除前保留的草稿"
        try SwiftDataDiaryRepository(context: container.mainContext).deleteDiary(id: entry.id, soft: !permanent)
        #expect(!session.save())
        #expect(session.issue == .missing && !session.canRevealContent)
        #expect(session.text == "删除前保留的草稿")
        #expect(try SwiftDataDiaryRepository(context: container.mainContext).fetchDiaries(for: nil, includeDeleted: false).isEmpty)
    }

    @Test func privacyIsMaskedOnOpenSaveAndExternalChangesWithoutChangingListPin() throws {
        let container = try fixture()
        let entry = try note(in: container, text: "#密码 synthetic-private")
        let session = DiaryEditorSession(source: .entry(entry), context: container.mainContext)
        #expect(!session.canRevealContent)
        session.isWindowPinned = true
        #expect(!entry.isPinned && !session.canRevealContent)
        session.reveal()
        #expect(session.canRevealContent)
        session.text += " edited"
        #expect(session.save())
        #expect(!session.canRevealContent)
        session.reveal()
        try SwiftDataDiaryRepository(context: container.mainContext).editDiary(id: entry.id, text: "#密码 external-update")
        session.refresh()
        #expect(!session.canRevealContent && session.text == entry.text)
    }

    @Test func selectedAndDeletedPrivateTagsStillProtectTransferredDrafts() throws {
        let container = try fixture()
        let tag = TagItem(name: "密码", sortOrder: 0, deletedAt: .now)
        container.mainContext.insert(tag)
        try container.mainContext.save()
        let draft = BoardComposerDraft(text: "synthetic secret", selectedTagIDs: [tag.id])
        let session = DiaryEditorSession(source: .draft(draft, dayKey: "2026-09-13"), context: container.mainContext)
        #expect(session.isSensitive && !session.canRevealContent)
    }

    @Test func closingRequiresSuccessfulSaveOrExplicitDiscard() throws {
        let container = try fixture()
        let draft = BoardComposerDraft(text: "关闭前需要保存")
        let session = DiaryEditorSession(source: .draft(draft, dayKey: "2026-09-13"), context: container.mainContext,
                                         commit: { _ in throw CocoaError(.fileWriteNoPermission) })
        #expect(!DiaryWindowController.canClose(session, choice: .cancel))
        #expect(!DiaryWindowController.canClose(session, choice: .save))
        #expect(session.hasUnsavedChanges && session.text == draft.text)
        #expect(DiaryWindowController.canClose(session, choice: .discard))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
    }

    @Test func summaryIsBoundedAndWhitespaceDoesNotConsumeExtraRows() {
        #expect(DiarySummaryRow.preview("  第一行\n\n第二行\t内容  ") == "第一行 第二行 内容")
        let long = DiarySummaryRow.preview(String(repeating: "长", count: 50_000))
        #expect(long.count == 401 && long.hasSuffix("…"))
    }

    private func fixture() throws -> ModelContainer {
        try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func note(in container: ModelContainer, text: String = "原始记录") throws -> DiaryEntry {
        let entry = DiaryEntry(text: text, dayKey: "2026-09-13")
        container.mainContext.insert(entry)
        try container.mainContext.save()
        return entry
    }
}
