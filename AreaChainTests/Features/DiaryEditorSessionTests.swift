import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryEditorSessionTests {
    private static var retainedContainers: [ModelContainer] = []
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

    @Test func pendingAttachmentsStayInMemoryUntilSavedAndRollbackOnFailure() throws {
        let container = try fixture()
        let context = container.mainContext
        let root = FileManager.default.temporaryDirectory
            .appending(path: "areachain-diary-staged-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AttachmentStore(root: root)
        var rejectsSave = true
        let session = DiaryEditorSession(
            source: .draft(BoardComposerDraft(text: "#123 你好"), dayKey: "2026-09-13"),
            context: context, attachmentStore: store,
            commit: { ctx in
                if rejectsSave { throw CocoaError(.fileWriteNoPermission) }
                try ctx.save()
            }
        )
        let board = NSPasteboard(name: .init("areachain.diary.paste.\(UUID().uuidString)"))
        defer { board.clearContents() }
        let png = try #require(ImageBytes.png(from: syntheticImage()))
        board.clearContents()
        board.setData(png, forType: .png)

        #expect(session.pasteAttachment(from: board))
        #expect(session.pendingAttachments.count == 1)
        let cancelledID = try #require(session.pendingAttachments.first?.id)
        session.removeAttachment(id: cancelledID)
        #expect(session.pendingAttachments.isEmpty)

        #expect(session.pasteAttachment(from: board))
        #expect(session.pendingAttachments.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)

        let stagedID = try #require(session.pendingAttachments.first?.id)
        #expect(!session.save())
        #expect(session.pendingAttachments.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(id: stagedID).path))

        rejectsSave = false
        #expect(session.save())
        #expect(session.pendingAttachments.isEmpty && !session.hasUnsavedChanges)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        let savedAttachment = try #require(context.fetch(FetchDescriptor<AttachmentItem>()).first)
        #expect(savedAttachment.id == stagedID && savedAttachment.ownerID == session.entryID)
        #expect(FileManager.default.fileExists(atPath: store.fileURL(id: stagedID).path))

        session.removeAttachment(id: stagedID)
        #expect(session.hasUnsavedChanges && savedAttachment.deletedAt == nil)
        #expect(session.save())
        #expect(savedAttachment.deletedAt != nil && !session.hasUnsavedChanges)
    }

    @Test func commandVInEditorStagesImageWhenPasteboardHasImageOnly() throws {
        let container = try fixture()
        let session = DiaryEditorSession(
            source: .draft(BoardComposerDraft(text: "快捷键粘贴图片"), dayKey: "2026-09-13"),
            context: container.mainContext
        )
        let controller = DiaryWindows().openDraft(
            BoardComposerDraft(text: "快捷键粘贴图片"), dayKey: "2026-09-13",
            context: container.mainContext, activate: false
        )
        defer { controller.window.close() }
        controller.window.contentView?.layoutSubtreeIfNeeded()
        let editor = try #require(findEditor(in: controller.window.contentView))
        _ = controller.window.makeFirstResponder(editor)
        let board = NSPasteboard(name: .init("areachain.diary.cmdv.\(UUID().uuidString)"))
        defer { board.clearContents() }
        editor.pasteboard = board
        let png = try #require(ImageBytes.png(from: syntheticImage()))
        board.clearContents()
        board.setData(png, forType: .png)

        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0,
            windowNumber: controller.window.windowNumber, context: nil,
            characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9
        ))
        #expect(editor.performKeyEquivalent(with: event))
        #expect(controller.session.pendingAttachments.count == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        _ = session
    }

    @Test func titleAndBodyRoundTripAndWindowHeadingDistinguishesBodyOnly() throws {
        let container = try fixture()
        let context = container.mainContext
        let locale = Locale(identifier: "zh-Hans")

        let untitled = DiaryEditorSession(source: .draft(BoardComposerDraft(), dayKey: "2026-09-13"), context: context)
        #expect(untitled.windowHeading(locale: locale) == "新手记")
        #expect(untitled.showsWindowUnsavedBadge)
        untitled.text = "第一行纯正文\n第二行纯正文"
        #expect(untitled.windowHeading(locale: locale) == "第一行纯正文")
        #expect(untitled.showsWindowUnsavedBadge)
        #expect(untitled.save())
        #expect(!untitled.showsWindowUnsavedBadge)
        #expect(untitled.windowHeading(locale: locale) == "第一行纯正文")
        let savedUntitled = try #require(untitled.record)
        #expect(!savedUntitled.hasExplicitTitle)

        let reopenedUntitled = DiaryEditorSession(source: .entry(savedUntitled), context: context)
        #expect(reopenedUntitled.title.isEmpty)
        #expect(reopenedUntitled.text == "第一行纯正文\n第二行纯正文")

        let titled = DiaryEditorSession(source: .draft(BoardComposerDraft(), dayKey: "2026-09-13"), context: context)
        titled.title = "周会纪要"
        titled.text = "1. 确认排期\n2. 接口联调"
        #expect(titled.windowHeading(locale: locale) == "周会纪要")
        #expect(titled.showsWindowUnsavedBadge)
        #expect(titled.save())
        #expect(!titled.showsWindowUnsavedBadge)
        #expect(titled.windowHeading(locale: locale) == "周会纪要")
        let savedTitled = try #require(titled.record)
        #expect(savedTitled.hasExplicitTitle)
        #expect(savedTitled.text == "周会纪要\n1. 确认排期\n2. 接口联调")

        let reopenedTitled = DiaryEditorSession(source: .entry(savedTitled), context: context)
        #expect(reopenedTitled.title == "周会纪要")
        #expect(reopenedTitled.text == "1. 确认排期\n2. 接口联调")
        #expect(!reopenedTitled.hasUnsavedChanges)
    }

    @Test func attachmentCarouselStepsAndAdvancesOnRemoval() {
        let first = AttachmentRef(id: UUID(), filename: "1.png")
        let second = AttachmentRef(id: UUID(), filename: "2.png")
        let third = AttachmentRef(id: UUID(), filename: "3.png")
        let items = [first, second, third]

        #expect(AttachmentCarouselSelection.index(of: second.id, in: items) == 1)
        #expect(AttachmentCarouselSelection.adjacentID(from: first.id, delta: -1, in: items) == nil)
        #expect(AttachmentCarouselSelection.adjacentID(from: first.id, delta: 1, in: items) == second.id)
        #expect(AttachmentCarouselSelection.adjacentID(from: second.id, delta: 1, in: items) == third.id)
        #expect(AttachmentCarouselSelection.adjacentID(from: third.id, delta: 1, in: items) == nil)

        #expect(AttachmentCarouselSelection.nextIDAfterRemoving(first.id, in: items) == second.id)
        #expect(AttachmentCarouselSelection.nextIDAfterRemoving(third.id, in: items) == second.id)
        #expect(AttachmentCarouselSelection.nextIDAfterRemoving(first.id, in: [first]) == nil)

        let rect1 = AttachmentCarouselSelection.anchorRect(
            for: first.id, in: items, thumbnailSize: 22, spacing: 4, cellPadding: 0
        )
        let rect2 = AttachmentCarouselSelection.anchorRect(
            for: second.id, in: items, thumbnailSize: 22, spacing: 4, cellPadding: 0
        )
        let rect3 = AttachmentCarouselSelection.anchorRect(
            for: third.id, in: items, thumbnailSize: 22, spacing: 4, cellPadding: 0
        )
        #expect(rect1 == CGRect(x: 0, y: 0, width: 22, height: 22))
        #expect(rect2 == CGRect(x: 26, y: 0, width: 22, height: 22))
        #expect(rect3 == CGRect(x: 52, y: 0, width: 22, height: 22))
    }

    private func findEditor(in view: NSView?) -> DaybookAppKitTextView? {
        guard let view else { return nil }
        if let editor = view as? DaybookAppKitTextView { return editor }
        for subview in view.subviews {
            if let found = findEditor(in: subview) { return found }
        }
        return nil
    }

    private func syntheticImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        return image
    }

    private func fixture() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        return container
    }

    private func note(in container: ModelContainer, text: String = "原始记录") throws -> DiaryEntry {
        let entry = DiaryEntry(text: text, dayKey: "2026-09-13")
        container.mainContext.insert(entry)
        try container.mainContext.save()
        return entry
    }
}
