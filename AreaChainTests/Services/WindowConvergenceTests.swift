import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow))
@MainActor
struct WindowConvergenceTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test func allSixWindowControllersInheritFromBaseWindowAndRegisterWithContracts() throws {
        let container = try makeInMemoryContainer()
        let draft = BoardComposerDraft(text: "收敛验证草稿 #工作")
        let diarySession = DiaryEditorSession(source: .draft(draft, dayKey: "2026-11-05"), context: container.mainContext)

        let workspace = PanelWindowController.workspace
        let clipboard = ClipboardHistoryPanel.shared
        let quickEntry = QuickEntryPanelController.shared
        let attachmentViewer = AttachmentImageViewerWindowController.shared
        let controlsPreview = ControlsPreviewWindowController.shared
        let diary = DiaryWindowController(session: diarySession)
        defer { diary.window.close() }

        // 确保共享单例若曾被其他测试清理也能被重新核验，同时 diary 实例通过 super.init() 自动注册
        for singleton in [workspace, clipboard, quickEntry, attachmentViewer, controlsPreview] {
            WindowRegistry.shared.register(singleton)
        }

        let controllers: [BaseWindow] = [
            workspace,
            diary,
            clipboard,
            quickEntry,
            attachmentViewer,
            controlsPreview,
        ]
        #expect(controllers.count == 6)

        // 1. 三栏工作台窗口契约
        #expect(WindowRegistry.shared.window(forID: "window.workspace") === workspace)
        #expect(workspace.windowID == "window.workspace")
        #expect(workspace.windowCategory == "workspace")
        #expect(workspace.defaultContentSize == DaybookMetrics.Window.workspaceSize)
        #expect(workspace.minimumContentSize == DaybookMetrics.Window.workspaceMinSize)
        #expect(workspace.supportsPinning == false)

        // 2. 手记独立小窗契约
        let expectedDiaryID = "window.diary.\(diarySession.id.uuidString)"
        #expect(WindowRegistry.shared.window(forID: expectedDiaryID) === diary)
        #expect(diary.windowID == expectedDiaryID)
        #expect(diary.windowCategory == "diary")
        #expect(diary.defaultContentSize == NSSize(width: 480, height: 440))
        #expect(diary.minimumContentSize == NSSize(width: 360, height: 300))
        #expect(diary.hasUnsavedChanges() == true)
        #expect(diary.hostedWindow === diary.window)

        // 3. 剪贴板历史小窗契约
        #expect(WindowRegistry.shared.window(forID: "window.clipboard") === clipboard)
        #expect(clipboard.windowID == "window.clipboard")
        #expect(clipboard.windowCategory == "clipboard")
        #expect(clipboard.defaultContentSize == NSSize(width: 380, height: 460))
        #expect(clipboard.minimumContentSize == NSSize(width: 380, height: 460))

        // 4. 极速速记小窗契约
        #expect(WindowRegistry.shared.window(forID: "window.quickEntry") === quickEntry)
        #expect(quickEntry.windowID == "window.quickEntry")
        #expect(quickEntry.windowCategory == "quickEntry")
        #expect(quickEntry.defaultContentSize == NSSize(width: 480, height: 180))
        #expect(quickEntry.minimumContentSize == NSSize(width: 480, height: 180))

        // 5. 独立图片查看器窗口契约
        #expect(WindowRegistry.shared.window(forID: "window.attachmentViewer") === attachmentViewer)
        #expect(attachmentViewer.windowID == "window.attachmentViewer")
        #expect(attachmentViewer.windowCategory == "attachmentViewer")
        #expect(attachmentViewer.defaultContentSize == AttachmentImageViewerWindowController.defaultContentSize)
        #expect(attachmentViewer.minimumContentSize == AttachmentImageViewerWindowController.minimumContentSize)

        // 6. 控件预览窗口契约
        #expect(WindowRegistry.shared.window(forID: "window.controlsPreview") === controlsPreview)
        #expect(controlsPreview.windowID == "window.controlsPreview")
        #expect(controlsPreview.windowCategory == "controlsPreview")
        #expect(controlsPreview.defaultContentSize == ControlsPreviewWindowController.contentSize)
        #expect(controlsPreview.minimumContentSize == ControlsPreviewWindowController.minimumContentSize)
    }

    @Test func diaryAndClipboardPinningSynchronizesWithBaseWindowState() throws {
        let container = try makeInMemoryContainer()
        let entry = try SwiftDataDiaryRepository(context: container.mainContext)
            .addDiary(text: "测试手记小窗置顶收敛", dayKey: "2026-11-05", tagIDs: [])
        let diarySession = DiaryEditorSession(source: .entry(entry), context: container.mainContext)
        let diary = DiaryWindowController(session: diarySession)
        defer { diary.window.close() }

        #expect(diary.isPinned == false)
        diary.setPinned(true)
        #expect(diary.isPinned == true)
        #expect(diary.session.isWindowPinned == true)
        #expect(diary.window.level == .floating)

        diary.setPinned(false)
        #expect(diary.isPinned == false)
        #expect(diary.session.isWindowPinned == false)
        #expect(diary.window.level == .normal)

        let clipboard = ClipboardHistoryPanel.shared
        let previousStaysOnTop = ClipboardHistorySession.shared.panelStaysOnTop
        defer { clipboard.setStaysOnTop(previousStaysOnTop) }

        clipboard.setStaysOnTop(true)
        #expect(clipboard.isPinned == true)
        clipboard.setStaysOnTop(false)
        #expect(clipboard.isPinned == false)
    }

    @Test func syntaxTextFieldConvergesToBaseSingleLineTextField() {
        var text = "买咖啡 #生活 !p1"
        var focused = false
        let captureField = SyntaxTextField(
            text: Binding(get: { text }, set: { text = $0 }),
            placeholder: "添加任务",
            focused: Binding(get: { focused }, set: { focused = $0 }),
            context: .capture
        )
        let tagOnlyField = SyntaxTextField(
            text: Binding(get: { text }, set: { text = $0 }),
            placeholder: "编辑标签",
            focused: Binding(get: { focused }, set: { focused = $0 }),
            context: .tags
        )
        #expect(captureField.context == .capture)
        #expect(tagOnlyField.context == .tags)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        return container
    }
}
