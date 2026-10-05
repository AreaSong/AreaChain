import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

extension MenuBarHelpSurfaceTests {
    @Test(arguments: ["send", "queue"])
    func helpBlankAndBackdropDoNotActivateContent(delivery: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic task"
        composer.diary.text = "Synthetic diary"
        let toolbar = MenuBarToolbarState()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let native = MenuBarPopoverRenderingTests()
        let filterPoint = try native.filterTriggerPoint(in: window)
        let diaryButton = try SettingsButtonTestSupport.button("capture.diary", in: window)
        let diaryRect = try SettingsButtonTestSupport.frame(diaryButton, in: window)
        let root = try #require(window.contentView)
        let tabPoint = NSPoint(x: root.bounds.width - 48, y: root.bounds.height - 29)
        for point in [filterPoint, tabPoint, NSPoint(x: diaryRect.midX, y: diaryRect.midY)] {
            try await openHelp(in: window)
            let row = try helpButton("syntax.guide.tag", context: .capture, locale: "en", in: window)
            let rect = try SettingsButtonTestSupport.frame(row, in: window)
            // 卡片宽度内、第一行左侧 padding；不是按钮也不是卡片外遮罩。
            try await SurfaceEventTestSupport.click(NSPoint(x: rect.minX - 5, y: rect.midY), in: window, delivery: delivery)
            #expect(helpVisible(window))
            try await SurfaceEventTestSupport.click(point, in: window, delivery: delivery)
            try await settledHelp(window)
            #expect(!helpVisible(window) && !toolbar.isFiltering)
            #expect(captureField(window) != nil, "关闭点击不能同时切换手记页签")
            #expect(composer.tasks.text == "Synthetic task" && composer.diary.text == "Synthetic diary")
        }
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 0)
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(!support.container.mainContext.hasChanges)
    }

    @Test func diaryEntryHelpUsesOriginalCaptureContext() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic task"
        composer.diary.text = "Synthetic diary"
        let window = helpWindow(support, composer: composer, toolbar: MenuBarToolbarState())
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await helpKey(124, chars: "\u{F703}", modifiers: .command, in: window)
        #expect(captureField(window) == nil)
        try await openHelp(in: window)
        #expect(helpVisible(window) && captureField(window) != nil)
        try await helpKey(53, in: window)
        #expect(!helpVisible(window))
        #expect(composer.tasks.text == "Synthetic task" && composer.diary.text == "Synthetic diary")
        #expect(!support.container.mainContext.hasChanges)
    }
}
