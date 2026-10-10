import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 只由完整 CM1 PrivacyQA 的显式选择器开启；按钮只操作合成内存 vault。
@Suite(.serialized) @MainActor struct CommandTextInteractiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AREACHAIN_CM1_INTERACTIVE"] == "1"))
    func nativeInputWindow() async throws {
        let marker = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]
        let audit: [String: Bool] = ["markerPresent": marker != nil, "markerEmpty": marker?.isEmpty == true,
                                    "testFrameworkPresent": NSClassFromString("XCTestCase") != nil,
                                    "expectedBundle": Bundle.main.bundleIdentifier == CommandTextQAWindowLease.bundle]
        Attachment.record(try JSONSerialization.data(withJSONObject: audit), named: "CM1R-test-marker.json")
        let lease = try CommandTextQAWindowLease()
        let synthetic = try ProtectedDraftFixture()
        let f = try UnifiedSearchResultsFixture(testVault: synthetic.vault)
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: synthetic.vault)
        try f.startOperation("todo.notes")
        let controls = CommandTextInteractiveControls(fixture: f, synthetic: synthetic)
        let window = NSWindow(contentViewController: NSHostingController(rootView: CommandTextInteractiveView(controls: controls)))
        window.isReleasedWhenClosed = false
        window.title = "AreaChain C-M1-R — 长段输入验收"
        window.setContentSize(NSSize(width: 820, height: 700))
        defer { SystemPageHost.release(window); window.close() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try f.session.resumeDisplay(expecting: f.controller.buffer.lease)
        f.controller.refreshOperationPresentation()
        let automatedProbe = ProcessInfo.processInfo.environment["AREACHAIN_CM1_AUTOCLOSE"] == "1"
        let preparation = ContinuousClock.now
        // 启动约束探针只验证窗口来源/就绪/退出；不能作为 1MiB 性能或真人输入证据。
        if !automatedProbe { try await controls.prepareLongDocument(in: window) }
        let duration = preparation.duration(to: .now).components
        let prepareMS = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
        try lease.write("ready", window: window, force: true)
        try controls.snapshot(window, at: lease.directory.appending(path: "ready.png"))
        let opened = ContinuousClock.now
        let deadline = opened + .seconds(300)
        var sawMarked = false
        var revisions = 0
        while !controls.finished && ContinuousClock.now < deadline {
            if automatedProbe, ContinuousClock.now > opened + .seconds(8) { controls.finished = true }
            if let editor = f.controller.longTextEditing?.editor {
                sawMarked = sawMarked || editor.hasMarkedText()
                revisions = max(revisions, editor.checkpointCount)
            }
            try lease.write("ready", window: window, locks: controls.locks)
            try await Task.sleep(for: .milliseconds(30))
        }
        try lease.write(controls.finished ? "finished" : "expired", window: window, locks: controls.locks, force: true)
        // 只记录状态/计数；是否真实输入法由实际桌面操作证据判断。
        Attachment.record("finished=\(controls.finished) markedObserved=\(sawMarked) maxAccepted=\(revisions) memoryLocks=\(controls.locks) automatedWindowProbe=\(automatedProbe) prepareMS=\(prepareMS)",
                          named: "CM1-interactive-metadata.txt")
        #expect(controls.finished, "隔离窗口到期；真实输入链未完整执行")
        #expect(try f.handoff.state().execution == nil)
    }
}

@Observable @MainActor final class CommandTextInteractiveControls {
    let fixture: UnifiedSearchResultsFixture
    let synthetic: ProtectedDraftFixture
    var finished = false
    var locks = 0
    var status = "仅合成数据；不会保存业务正文。"
    init(fixture: UnifiedSearchResultsFixture, synthetic: ProtectedDraftFixture) {
        self.fixture = fixture
        self.synthetic = synthetic
    }
    func prepareLongDocument(in window: NSWindow) async throws {
        let controller = fixture.controller!
        controller.beginLongText(.notes, source: controller.buffer)
        try await SystemPageHost.settle(window)
        let ordinary = try #require(controller.longTextEditing?.editor)
        ordinary.insertText(String(repeating: "中a🙂", count: 131_072), replacementRange: .init(location: 0, length: ordinary.string.utf16.count))
        controller.protectLongText(source: controller.buffer)
        try #require(controller.editingDraft?.protectedReference != nil)
        try await SystemPageHost.settle(window)
        controller.beginLongText(.notes, source: controller.buffer)
        try await SystemPageHost.settle(window)
        let editor = try #require(controller.longTextEditing?.editor)
        try #require(editor.access?.isProtected == true)
        try #require(window.makeFirstResponder(editor))
        editor.scrollRangeToVisible(.init(location: editor.string.utf16.count, length: 0))
        try await SystemPageHost.settle(window)
        status = "已载入1MiB受保护合成长段；仅检查末尾中文输入、候选位置与滚动。"
    }

    func snapshot(_ window: NSWindow, at url: URL) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
    }

    func lock() { locks += 1; synthetic.vault.lock(); status = "合成 vault 已锁定" }
    func unlock() async {
        do {
            try synthetic.unlock()
            try await Task.sleep(for: .milliseconds(180))
            // 锁定已清查询，显式重入合成页面，不用旧查询绕过 pageContextRequired。
            try fixture.handoff.send(.query(.enterPage(QuerySessionFixture.page(.overview, host: HandoffFixture.source))))
            let controller = fixture.controller!
            _ = controller.publishOperation(text: "/tasks/notes")
            try fixture.session.resumeDisplay(expecting: controller.buffer.lease)
            try await Task.sleep(for: .milliseconds(180))
            _ = try await fixture.publish()
            _ = controller.beginOperation(.init(rawValue: "todo.notes"), source: controller.buffer)
            status = "已解锁；正文仍需显式恢复"
        } catch { status = "恢复显示失败；原草稿仍保留" }
    }
}

private struct CommandTextInteractiveView: View {
    @Bindable var controls: CommandTextInteractiveControls
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("C-M1-R 受保护合成长段验收").font(.headline)
            HStack {
                Button("锁定合成 vault") { controls.lock() }
                Button("解锁合成 vault") { Task { await controls.unlock() } }
                Button("完成本轮") { controls.finished = true }
            }
            Text(controls.status)
            UnifiedSearchOperationPanel(controller: controls.fixture.controller)
        }
        .padding(16)
        .environment(\.locale, Locale(identifier: "zh-Hans"))
        .preferredColorScheme(.light)
    }
}
