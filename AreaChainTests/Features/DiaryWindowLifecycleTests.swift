import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryWindowLifecycleTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test func sameRecordReusesWindowAndWindowPinDoesNotChangeListPinOrFocus() throws {
        let container = try fixture()
        let entry = try SwiftDataDiaryRepository(context: container.mainContext)
            .addDiary(text: "置顶窗口测试", dayKey: "2026-09-13", tagIDs: [])
        let manager = DiaryWindows()
        let controller = manager.open(entry: entry, context: container.mainContext, activate: false)
        defer { controller.window.close() }
        #expect(manager.open(entry: entry, context: container.mainContext, activate: false) === controller)
        #expect(manager.hostedWindows.count == 1)
        #expect(controller.window.level == .normal)
        let keyWindow = NSApp.keyWindow
        controller.setPinned(true)
        #expect(controller.window.level == .floating && controller.session.isWindowPinned)
        #expect(NSApp.keyWindow === keyWindow)
        #expect(!entry.isPinned)
        controller.setPinned(false)
        #expect(controller.window.level == .normal)
        #expect(controller.window.styleMask.contains(.resizable))
        #expect(!controller.window.isRestorable && !controller.window.hidesOnDeactivate)
    }

    @Test func transferredDraftBecomesSameRecordWithoutDuplicateWindow() throws {
        let container = try fixture()
        let capture = DiaryCaptureSession()
        capture.draft.text = "转到小窗继续写 #工作"
        let original = capture.draft
        let manager = DiaryWindows()
        let controller = manager.openDraft(original, dayKey: "2026-09-13", context: container.mainContext,
                                          activate: false) { capture.draft = DiaryComposerDraft() }
        defer { controller.window.close() }
        #expect(capture.draft.text.isEmpty && capture.draft.id != original.id)
        #expect(controller.session.text == original.text)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(manager.openDraft(original, dayKey: "2026-09-13", context: container.mainContext, activate: false) === controller)
        #expect(controller.session.save())
        let entry = try #require(controller.session.record)
        #expect(manager.open(entry: entry, context: container.mainContext, activate: false) === controller)
        #expect(manager.hostedWindows.count == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        controller.window.close()
        #expect(manager.hostedWindows.isEmpty)
    }

    @Test func auxiliaryWindowSurvivesWorkspaceCleanupAndRemasksWhenLeavingIt() throws {
        let container = try fixture()
        let entry = try SwiftDataDiaryRepository(context: container.mainContext)
            .addDiary(text: "#密码 synthetic-window-value", dayKey: "2026-09-13", tagIDs: [])
        let manager = DiaryWindows()
        let controller = manager.open(entry: entry, context: container.mainContext, activate: false)
        let previousProvider = AppWindows.diaryWindowsProvider
        AppWindows.diaryWindowsProvider = { manager.hostedWindows }
        defer { controller.window.close(); AppWindows.diaryWindowsProvider = previousProvider }
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        parent.orderFront(nil)
        AppWindows.resignIfIdle(closing: parent)
        parent.close()
        #expect(controller.window.isVisible)
        #expect(!controller.session.canRevealContent)
        controller.session.reveal()
        #expect(controller.session.canRevealContent)
        controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: controller.window))
        #expect(!controller.session.canRevealContent)
    }

    @Test func nativeCloseSheetCanCancelThenSaveWithoutLosingText() async throws {
        let container = try fixture()
        let manager = DiaryWindows()
        let controller = manager.openDraft(DiaryComposerDraft(text: "关闭确认中的草稿"), dayKey: "2026-09-13",
                                          context: container.mainContext, activate: false)
        defer { controller.window.close() }
        controller.window.performClose(nil)
        try await Task.sleep(for: .milliseconds(250))
        let sheet = try #require(controller.window.attachedSheet)
        let cancel = L10n.string("alert.cancel", locale: AppPreferences.shared.resolvedLocale)
        try #require(buttons(in: sheet.contentView).first { $0.title == cancel }).performClick(nil)
        try await Task.sleep(for: .milliseconds(250))
        #expect(controller.window.isVisible && controller.session.text == "关闭确认中的草稿")
        #expect(manager.hostedWindows.count == 1)
        controller.window.performClose(nil)
        try await Task.sleep(for: .milliseconds(250))
        let saveSheet = try #require(controller.window.attachedSheet)
        let save = L10n.string("common.save", locale: AppPreferences.shared.resolvedLocale)
        try #require(buttons(in: saveSheet.contentView).first { $0.title == save }).performClick(nil)
        try await Task.sleep(for: .milliseconds(250))
        #expect(manager.hostedWindows.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<DiaryEntry>()).first?.text == "关闭确认中的草稿")
    }

    private func buttons(in view: NSView?) -> [NSButton] {
        guard let view else { return [] }
        return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }

    private func fixture() throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        Self.retainedContainers.append(container)
        return container
    }
}
