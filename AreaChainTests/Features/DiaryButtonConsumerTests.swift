import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载生产消费者，验证样式接入没有截断原按钮动作；不使用真实系统服务。
@Suite(.serialized) @MainActor
struct DiaryButtonConsumerTests {
    // SwiftUI 的延迟通知可能晚于窗口释放；沿现有窗口夹具保留内存容器。
    private static var retainedContainers: [ModelContainer] = []

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func windowSavePinAndFailure(locale: String, scheme: ColorScheme) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        var fail = true
        var commits = 0
        let session = DiaryEditorSession(source: .draft(BoardComposerDraft(), dayKey: "2026-10-01"),
                                         context: f.context, vault: f.vault, commit: { context in
            commits += 1
            if fail { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        })
        let window = host(DiaryWindowView(session: session, onPin: { session.isWindowPinned.toggle() }),
                          f: f, locale: locale, scheme: scheme, size: NSSize(width: 328, height: 230))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await click("common.save", locale: locale, in: window)
        #expect(commits == 0 && session.entryID == nil)
        try await click("diary.window.pin", locale: locale, in: window)
        #expect(session.isWindowPinned)
        try await click("diary.window.unpin", locale: locale, in: window)
        #expect(!session.isWindowPinned)
        session.text = "Synthetic draft with a long tag #abcdefghijklmnopqrstuvwxyz"
        try await SystemPageHost.settle(window)
        try await click("common.save", locale: locale, in: window)
        #expect(commits == 1 && session.issue == .failed && session.hasUnsavedChanges)
        #expect(session.text.contains("Synthetic draft") && window.isVisible)
        fail = false
        try await click("common.save", locale: locale, in: window)
        #expect(commits == 2 && session.entryID != nil && !session.hasUnsavedChanges)
        try snapshot(window, name: "window-\(locale)-\(scheme)")
    }

    @Test func revealMaskAndConflictKeepDraft() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        Self.retainedContainers.append(f.container)
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "Synthetic protected", dayKey: "2026-10-01", tagIDs: [tag.id])
        let session = DiaryEditorSession(source: .entry(note), context: f.context, vault: f.vault)
        let window = host(DiaryWindowView(session: session, onPin: {}), f: f, locale: "en",
                          scheme: .light, size: NSSize(width: 328, height: 230))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(!session.canRevealContent)
        try await click("common.save", locale: "en", in: window)
        #expect(!session.canRevealContent)
        try await click("diary.reveal", locale: "en", in: window)
        #expect(session.canRevealContent)
        session.text = "Synthetic local draft"
        try f.repository.editDiary(id: note.id, text: "Synthetic external change")
        session.reveal()
        try await SystemPageHost.settle(window)
        try await click("common.save", locale: "en", in: window)
        #expect(session.issue == .conflict && session.text == "Synthetic local draft")
        #expect(session.hasUnsavedChanges && window.isVisible)
        try await click("diary.mask", locale: "en", in: window)
        #expect(!session.canRevealContent && session.hasUnsavedChanges)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func cardSaveAndCancel(locale: String, scheme: ColorScheme) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let note = try f.repository.addDiary(text: "Synthetic original", dayKey: "2026-10-01", tagIDs: [])
        let drafts = DiaryCardDrafts()
        let session = drafts.begin(note, context: f.context, vault: f.vault)
        session.text = "Synthetic cancelled edit"
        let card = DiaryNoteCard(entry: note, activeTags: [], attachments: [], onDelete: {},
                                 draftStore: drafts, vault: f.vault)
        let window = host(card, f: f, locale: locale, scheme: scheme, size: NSSize(width: 328, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try snapshot(window, name: "card-\(locale)-\(scheme)")
        try await click("alert.cancel", locale: locale, in: window)
        #expect(drafts.editor(for: note.id) == nil && note.text == "Synthetic original")
        let next = drafts.begin(note, context: f.context, vault: f.vault)
        next.text = "Synthetic saved edit"
        try await SystemPageHost.settle(window)
        try await click("common.save", locale: locale, in: window)
        #expect(drafts.editor(for: note.id) == nil && note.text == "Synthetic saved edit")
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func tagSheetValidationFailureSuccessAndCancel(locale: String, scheme: ColorScheme) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        var names: [String] = []
        var succeeds = false
        let selector = TaskDetailTagSelector(tagIDs: "", tags: [], onToggleTag: { _ in }, onCreateTag: {
            names.append($0)
            return succeeds
        })
        let window = host(selector, f: f, locale: locale, scheme: scheme, size: NSSize(width: 360, height: 280))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await click("drawer.tag.add", locale: locale, in: window)
        let sheet = try #require(window.attachedSheet)
        try await prepareSheet(sheet)
        try await click("drawer.tag.create", locale: locale, in: sheet)
        #expect(names.isEmpty && window.attachedSheet != nil)
        try await enter("密码", in: sheet)
        try await click("drawer.tag.create", locale: locale, in: sheet)
        #expect(names.isEmpty)
        #expect(labels(in: sheet).contains(L10n.string("tag.preset.reserved", locale: Locale(identifier: locale))))
        let longName = "Synthetic long tag abcdefghijklmnopqrstuvwxyz"
        try await enter("  \(longName)  ", in: sheet)
        try await click("drawer.tag.create", locale: locale, in: sheet)
        #expect(names == [longName] && window.attachedSheet != nil)
        #expect(labels(in: sheet).contains(L10n.string("save.failure.title", locale: Locale(identifier: locale))))
        try snapshot(sheet, name: "tag-\(locale)-\(scheme)")
        succeeds = true
        try await click("drawer.tag.create", locale: locale, in: sheet)
        try await waitForSheetToClose(window)
        #expect(names == [longName, longName] && window.attachedSheet == nil)
        try await click("drawer.tag.add", locale: locale, in: window)
        let reopened = try #require(window.attachedSheet)
        try await prepareSheet(reopened)
        #expect(fields(in: reopened.contentView).first?.stringValue == "")
        try await enter("Cancelled", in: reopened)
        try await click("alert.cancel", locale: locale, in: reopened)
        try await waitForSheetToClose(window)
        #expect(names.count == 2 && window.attachedSheet == nil)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func sealedComposerKeepsDraftOnCancelAndDiscardsOnlyAfterConfirmation(locale: String, scheme: ColorScheme) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let drafts = BoardComposerSession(vault: f.vault)
        drafts.diary = BoardComposerDraft(text: "Synthetic sealed draft", needsProtection: true)
        try drafts.diary.seal(vault: f.vault)
        let originalID = drafts.diary.id
        f.vault.lock()
        let page = DiaryPage(todayKey: "2026-10-01", entries: [], options: DiaryPageOptions(
            showsPageHeader: false, composerDraft: Binding(get: { drafts.diary }, set: { drafts.diary = $0 }), vault: f.vault))
        let window = host(page, f: f, locale: locale, scheme: scheme, size: NSSize(width: 380, height: 230))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let unlock = try SettingsButtonTestSupport.button("privacy.unlock.title", locale: locale, in: window)
        let discard = try SettingsButtonTestSupport.button("privacy.draft.discard", locale: locale, in: window)
        try SettingsButtonTestSupport.assertBounds([unlock, discard], in: window)
        try snapshot(window, name: "sealed-composer-\(locale)-\(scheme)")
        try await SettingsButtonTestSupport.click(discard, in: window)
        #expect(drafts.diary.id == originalID && drafts.diary.sealed != nil)
        let sheet = try #require(window.attachedSheet)
        try await prepareSheet(sheet)
        try await click("alert.cancel", locale: locale, in: sheet)
        try await waitForSheetToClose(window)
        #expect(drafts.diary.id == originalID && drafts.diary.sealed != nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await click("privacy.draft.discard", locale: locale, in: window)
        let confirmation = try #require(window.attachedSheet)
        try await prepareSheet(confirmation)
        try await click("privacy.draft.discard", locale: locale, in: confirmation)
        try await waitForSheetToClose(window)
        #expect(drafts.diary.id != originalID && !drafts.diary.hasContent && drafts.diary.selectedTagIDs.isEmpty)
    }

    @Test func sealedComposerRestoresThroughOriginalButtonAndFocusCallback() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let drafts = BoardComposerSession(vault: f.vault)
        drafts.diary = BoardComposerDraft(text: "Synthetic restored draft", needsProtection: true)
        try drafts.diary.seal(vault: f.vault)
        let originalID = drafts.diary.id
        let page = DiaryPage(todayKey: "2026-10-01", entries: [], options: DiaryPageOptions(
            showsPageHeader: false, composerDraft: Binding(get: { drafts.diary }, set: { drafts.diary = $0 }), vault: f.vault))
        let window = host(page, f: f, locale: "en", scheme: .light, size: NSSize(width: 380, height: 230))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        // 替身 vault 已解锁但草稿仍封存，走原 PrivacyAccess 快路径而不触发系统认证。
        try await click("privacy.unlock.title", locale: "en", in: window)
        #expect(drafts.diary.id == originalID && drafts.diary.sealed == nil)
        #expect(drafts.diary.text == "Synthetic restored draft")
        let editor = try #require(window.firstResponder as? NSTextView)
        #expect(editor.string == "Synthetic restored draft")
    }

    private func host<Content: View>(_ content: Content, f: PrivacyFixture, locale: String,
                                     scheme: ColorScheme, size: NSSize) -> NSWindow {
        Self.retainedContainers.append(f.container)
        return SystemPageHost.window(content, container: f.container, scheme: scheme, locale: locale, size: size, embedded: false)
    }

    private func click(_ key: String, locale: String, in window: NSWindow) async throws {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        let button = try #require(elements(window.contentView).first {
            value($0, "accessibilityRole") as? String == "AXButton"
                && ((value($0, "accessibilityLabel") as? String) == title
                    || (value($0, "accessibilityTitle") as? String) == title)
        }, "未找到生产按钮：\(key)")
        let screenRect = try #require(button.value(forKey: "accessibilityFrame") as? NSValue).rectValue
        let rect = window.convertFromScreen(screenRect)
        let bounds = try #require(window.contentView).bounds
        #expect(rect.width > 0 && rect.height > 0)
        #expect(rect.minX >= 0 && rect.maxX <= bounds.width && rect.minY >= 0 && rect.maxY <= bounds.height)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: rect.midX, y: rect.midY),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
    }

    private func prepareSheet(_ sheet: NSWindow) async throws {
        try await NativeSyntaxUI.prepareFocus(in: sheet)
        // 等原生呈现过渡停止移动后再从 AX 坐标投递鼠标事件。
        var previous = sheet.frame
        var stable = 0
        let deadline = ContinuousClock.now + .seconds(2)
        while stable < 3 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
            stable = sheet.frame == previous ? stable + 1 : 0
            previous = sheet.frame
        }
        try #require(stable == 3 && sheet.isKeyWindow)
    }

    private func waitForSheetToClose(_ window: NSWindow) async throws {
        // AppKit sheet 的关闭过渡不受 SwiftUI transaction 禁动画控制。
        let deadline = ContinuousClock.now + .seconds(2)
        while window.attachedSheet != nil && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(window.attachedSheet == nil)
    }

    private func fields(in view: NSView?) -> [NSTextField] {
        guard let view else { return [] }
        if let field = view as? NSTextField, field.isEditable { return [field] }
        return view.subviews.flatMap { fields(in: $0) }
    }

    private func enter(_ text: String, in window: NSWindow) async throws {
        let field = try #require(fields(in: window.contentView).first)
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor())
        editor.string = text
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
        try await SystemPageHost.settle(window)
    }

    private func labels(in window: NSWindow) -> String {
        elements(window.contentView).compactMap {
            (value($0, "accessibilityLabel") ?? value($0, "accessibilityTitle") ?? value($0, "accessibilityValue")) as? String
        }.joined(separator: "\n")
    }

    private func value(_ node: NSObject, _ name: String) -> Any? {
        let selector = NSSelectorFromString(name)
        return node.responds(to: selector) ? node.perform(selector)?.takeUnretainedValue() : nil
    }

    private func elements(_ root: NSView?) -> [NSObject] {
        guard let root else { return [] }
        var queue: [NSObject] = [root]
        var visited = Set<ObjectIdentifier>()
        var result: [NSObject] = []
        while let node = queue.popLast() {
            guard visited.insert(ObjectIdentifier(node)).inserted else { continue }
            if let view = node as? NSView { queue.append(contentsOf: view.subviews) }
            result.append(node)
            if let children = value(node, "accessibilityChildren") as? [NSObject] {
                queue.append(contentsOf: children)
            }
        }
        return result
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainButtonConsumersQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: "\(name).png"))
    }
}
