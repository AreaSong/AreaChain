import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow))
@MainActor
struct BaseWindowTests {
    @Test func autoRegistrationActivationPolicyAndMultiWindowLookup() {
        var recordedPolicies: [NSApplication.ActivationPolicy] = []
        let registry = WindowRegistry(activationPolicyHandler: { policy in
            recordedPolicies.append(policy)
        })
        registry.ordersFrontOnOpen = false
        defer { registry.reset() }

        let workspace = MockTestWindow(
            id: "window.workspace",
            category: "workspace",
            title: "AreaChain 工作台",
            defaultSize: NSSize(width: 960, height: 640),
            minSize: NSSize(width: 780, height: 500),
            supportsPinning: false,
            registry: registry
        )
        let diaryOne = MockTestWindow(
            id: "diary.window.1",
            category: "diary",
            title: "周复盘手记",
            registry: registry
        )
        let diaryTwo = MockTestWindow(
            id: "diary.window.2",
            category: "diary",
            title: "读书摘录手记",
            registry: registry
        )

        #expect(registry.windows.count == 3)
        #expect(registry.currentActivationPolicy == .accessory)

        workspace.openWindow()
        #expect(registry.currentActivationPolicy == .regular)
        #expect(recordedPolicies.last == .regular)
        #expect(registry.lastActivatedWindow === workspace)

        diaryOne.openWindow()
        diaryTwo.openWindow()
        #expect(registry.lastActivatedWindow === diaryTwo)

        // 不传参默认返回最近激活窗口
        #expect(registry.findWindow() === diaryTwo)
        #expect(registry.findWindow(category: "diary") === diaryTwo)

        // 按 windowID 精确查找
        #expect(registry.findWindow(target: "diary.window.1") === diaryOne)
        #expect(registry.window(forID: "window.workspace") === workspace)

        // 按 1 基序号查找
        #expect(registry.findWindow(target: "1", category: "diary") === diaryOne)
        #expect(registry.findWindow(target: "#2", category: "diary") === diaryTwo)

        // 按标题关键词查找
        #expect(registry.findWindow(target: "周复盘") === diaryOne)
        #expect(registry.findWindow(target: "读书摘录") === diaryTwo)

        // 按窗口类别查找与 "all" 批量匹配
        let allDiary = registry.resolveWindows(target: "all", category: "diary")
        #expect(allDiary.count == 2)
        #expect(registry.resolveWindows(target: "diary").count == 2)
        #expect(registry.resolveWindows(target: "all").count == 3)

        // 批量关闭同类小窗后，剩余工作台仍保持 .regular
        let closedDiaryCount = registry.closeWindows(target: "all", category: "diary")
        #expect(closedDiaryCount == 2)
        #expect(registry.windows.count == 1)
        #expect(registry.currentActivationPolicy == .regular)

        // 最后一个窗口关闭后，自动切换回 .accessory
        #expect(workspace.closeWindow() == true)
        #expect(registry.windows.isEmpty)
        #expect(registry.currentActivationPolicy == .accessory)
    }

    @Test func pinningResizeMinSizeClampAndResignKeyNotification() {
        let registry = WindowRegistry(activationPolicyHandler: { _ in })
        registry.ordersFrontOnOpen = false
        defer { registry.reset() }

        let diary = MockTestWindow(
            id: "diary.pin.test",
            category: "diary",
            title: "置顶与尺寸测试",
            defaultSize: NSSize(width: 480, height: 420),
            minSize: NSSize(width: 360, height: 300),
            supportsPinning: true,
            registry: registry
        )
        let unpinnable = MockTestWindow(
            id: "workspace.unpinnable",
            category: "workspace",
            title: "主工作台",
            supportsPinning: false,
            registry: registry
        )

        diary.openWindow()
        unpinnable.openWindow()

        #expect(diary.isPinned == false)
        #expect(diary.hostedWindow?.level == .normal)

        let pinnedState = diary.togglePin()
        #expect(pinnedState == true)
        #expect(diary.isPinned == true)
        #expect(diary.hostedWindow?.level == .floating)

        diary.setPinned(false)
        #expect(diary.isPinned == false)
        #expect(diary.hostedWindow?.level == .normal)

        // 不支持置顶的窗口忽略置顶请求
        unpinnable.setPinned(true)
        #expect(unpinnable.isPinned == false)
        #expect(unpinnable.hostedWindow?.level == .normal)

        // 调整尺寸时严格遵守 minSize 下限
        diary.resize(width: 640, height: 520)
        let expandedSize = diary.hostedWindow?.contentView?.frame.size ?? .zero
        #expect(abs(expandedSize.width - 640) < 2)
        #expect(abs(expandedSize.height - 520) < 2)

        diary.resize(width: 180, height: 120)
        let clampedSize = diary.hostedWindow?.contentView?.frame.size ?? .zero
        #expect(abs(clampedSize.width - 360) < 2)
        #expect(abs(clampedSize.height - 300) < 2)

        diary.centerOnActiveScreen()
        #expect(diary.hostedWindow != nil)

        // 验证窗口失焦通知
        var notifiedWindowID: String?
        let token = NotificationCenter.default.addObserver(
            forName: WindowRegistry.windowDidResignKeyNotification,
            object: diary,
            queue: .main
        ) { notification in
            notifiedWindowID = notification.userInfo?["windowID"] as? String
        }
        defer { NotificationCenter.default.removeObserver(token) }

        diary.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: diary.hostedWindow))
        #expect(registry.lastResignedWindowID == "diary.pin.test")
        #expect(notifiedWindowID == "diary.pin.test")
    }

    @Test func unsavedChangesInterceptionBlocksNormalCloseUntilConfirmedOrForced() {
        let registry = WindowRegistry(activationPolicyHandler: { _ in })
        registry.ordersFrontOnOpen = false
        defer { registry.reset() }

        let editorWindow = MockTestWindow(
            id: "diary.unsaved",
            category: "diary",
            title: "未保存手记",
            registry: registry
        )
        editorWindow.unsaved = true
        editorWindow.allowUnsavedClose = false
        editorWindow.openWindow()
        editorWindow.syncWindowChrome()

        #expect(editorWindow.hostedWindow?.isDocumentEdited == true)
        #expect(editorWindow.confirmPromptCount == 0)

        // 存在未保存修改且用户拒绝/取消确认时，拦截关闭
        let closedFirstAttempt = editorWindow.closeWindow(force: false)
        #expect(closedFirstAttempt == false)
        #expect(editorWindow.confirmPromptCount == 1)
        #expect(editorWindow.isOpen == true)
        #expect(registry.window(forID: "diary.unsaved") != nil)

        if let nsWindow = editorWindow.hostedWindow {
            #expect(editorWindow.windowShouldClose(nsWindow) == false)
            #expect(editorWindow.confirmPromptCount == 2)
        }

        // 强制关闭（force: true）可绕过拦截完成清理
        let forceClosed = editorWindow.closeWindow(force: true)
        #expect(forceClosed == true)
        #expect(editorWindow.isOpen == false)
        #expect(editorWindow.hostedWindow == nil)
        #expect(registry.window(forID: "diary.unsaved") == nil)
    }
}

@MainActor
private final class MockTestWindow: BaseWindow {
    private let idValue: String
    private let categoryValue: String
    var titleValue: String
    private let defaultSizeValue: NSSize
    private let minSizeValue: NSSize
    private let supportsPinningValue: Bool
    var unsaved = false
    var allowUnsavedClose = true
    private(set) var confirmPromptCount = 0

    init(
        id: String,
        category: String,
        title: String,
        defaultSize: NSSize = NSSize(width: 480, height: 360),
        minSize: NSSize = NSSize(width: 320, height: 240),
        supportsPinning: Bool = true,
        registry: WindowRegistry
    ) {
        self.idValue = id
        self.categoryValue = category
        self.titleValue = title
        self.defaultSizeValue = defaultSize
        self.minSizeValue = minSize
        self.supportsPinningValue = supportsPinning
        super.init(registry: registry)
    }

    override var windowID: String { idValue }
    override var windowCategory: String { categoryValue }
    override var windowTitle: String { titleValue }
    override var defaultSize: NSSize { defaultSizeValue }
    override var minSize: NSSize { minSizeValue }
    override var supportsPinning: Bool { supportsPinningValue }

    override func hasUnsavedChanges() -> Bool {
        unsaved
    }

    override func confirmCloseIfUnsaved() -> Bool {
        confirmPromptCount += 1
        return allowUnsavedClose
    }

    override func makeRootView() -> AnyView {
        AnyView(Text(verbatim: titleValue).frame(maxWidth: .infinity, maxHeight: .infinity))
    }
}
