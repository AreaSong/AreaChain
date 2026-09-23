import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryComposerInteractionTests {
    @Test func commandReturnSavesOnceKeepingFocusAndFixedHeight() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("单行手记内容")
        let initialFrame = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        #expect(initialFrame.height <= 36)
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.lastSaved == "单行手记内容")
        #expect(host.draft.submissions == 1 && host.draft.text.isEmpty)
        let emptyFrame = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        #expect(emptyFrame.height <= 36)
    }

    @Test func emptyOrWhitespaceCannotBeSavedByButtonOrShortcut() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.click("syntax.commandReturn.button")
        try await host.pressReturn(modifiers: .command)
        try await host.enter("   ")
        try await host.click("syntax.commandReturn.button")
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.submissions == 0)
        #expect(host.draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func clickingTheInlineShortcutAndPopoutUseSeparateActions() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("点击保存的手记")
        try await host.click("syntax.commandReturn.button")
        #expect(host.draft.submissions == 1 && host.draft.lastSaved == "点击保存的手记")
        try await host.enter("转到小窗的手记")
        try await host.click("syntax.diary.popout")
        #expect(host.draft.popouts == 1 && host.draft.transferred == "转到小窗的手记")
        #expect(host.draft.submissions == 1)
    }

    @Test func chineseCompositionAndTagCompletionTakePriorityOverSubmission() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        let editor = try await host.focus()
        editor.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        try await host.settle()
        #expect(editor.hasMarkedText())
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.submissions == 0 && editor.hasMarkedText())
        editor.unmarkText()
        try await host.settle()
    }

    @Test func failedSaveKeepsDraftAndFixedRowHeight() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("失败时继续保留的内容")
        let before = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        #expect(before.height <= 36)
        host.draft.rejectSave = true
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.text == "失败时继续保留的内容")
        #expect(host.draft.status == "diary.window.save.failed")
        #expect(try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window) == before)
        try host.snapshot("note-composer-save-failed")
    }

    @Test(arguments: ["zh-Hans", "en"], [ColorScheme.light, .dark])
    func actionsRemainBesideFixedEditorInBothLanguagesAndAppearances(locale: String, scheme: ColorScheme) async throws {
        let host = try DiaryComposerHost(locale: locale, scheme: scheme)
        defer { host.close() }
        _ = try await host.focus()
        let row = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        let button = try NativeSyntaxUI.frame("syntax.commandReturn.button", in: host.window)
        let popout = try NativeSyntaxUI.frame("syntax.diary.popout", in: host.window)
        #expect(row.height <= 36)
        #expect(button.minX >= popout.maxX)
        #expect(abs(button.midY - popout.midY) < 2)
        let appearance = scheme == .dark ? "dark" : "light"
        try host.snapshot("note-composer-empty-\(locale)-\(appearance)")
        try await host.enter("保持单行固定高度。Fixed-height single-line note.")
        let longRow = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        #expect(longRow.height <= 36)
        try host.snapshot("note-composer-long-\(locale)-\(appearance)")
    }

    @Test func commandModifierEmphasizesTheSameButtonWithoutMovingIt() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("按住 Command 高亮保存")
        try await host.postModifiers([])
        let frame = try NativeSyntaxUI.frame("syntax.commandReturn.button", in: host.window)
        let idle = try host.buttonPixels()
        try await host.postModifiers(.command)
        let active = try host.buttonPixels()
        #expect(idle != active)
        let activeFrame = try NativeSyntaxUI.frame("syntax.commandReturn.button", in: host.window)
        #expect(abs(frame.midX - activeFrame.midX) < 1 && abs(frame.midY - activeFrame.midY) < 1)
        try host.snapshot("note-composer-command-highlight")
        try await host.postModifiers([])
        #expect(try host.buttonPixels() == idle)
    }

    @Test func capsLockDoesNotChangeTheCommandReturnAction() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("Caps Lock 下的手记")
        try await host.pressReturn(modifiers: [.command, .capsLock])
        #expect(host.draft.submissions == 1 && host.draft.lastSaved == "Caps Lock 下的手记")
    }
}

@Observable @MainActor
private final class DiaryComposerProbe {
    var text = ""
    var focused = true
    var tagIDs: Set<UUID> = []
    var status: String?
    var rejectSave = false
    var submissions = 0
    var lastSaved = ""
    var popouts = 0
    var transferred = ""

    func submit() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if rejectSave { status = "diary.window.save.failed"; return }
        submissions += 1
        lastSaved = text
        text = ""
        focused = true
        status = "diary.window.saved"
    }

    func popout() { popouts += 1; transferred = text }
}

@MainActor
private final class DiaryComposerHost {
    private static var retainedContainers: [ModelContainer] = []
    let draft = DiaryComposerProbe()
    let window: NSWindow

    init(locale: String = "zh-Hans", scheme: ColorScheme = .light) throws {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(TagItem(name: "工作", sortOrder: 0))
        try container.mainContext.save()
        Self.retainedContainers.append(container)
        let hosting = NSHostingView(rootView: ComposerProbeView(probe: draft)
            .padding(12).frame(width: 380, height: 200, alignment: .top)
            .modelContainer(container).environment(AppPreferences.shared)
            .environment(\.locale, Locale(identifier: locale))
            .preferredColorScheme(scheme).background(DaybookPalette.fill.page)
            .transaction { $0.disablesAnimations = true }.syntaxOverlayHost())
        hosting.safeAreaRegions = []
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window.contentView = nil; window.orderOut(nil) }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func findTextField(_ view: NSView?) -> DaybookAppKitTextField? {
        guard let view else { return nil }
        if let tf = view as? DaybookAppKitTextField { return tf }
        return view.subviews.lazy.compactMap { self.findTextField($0) }.first
    }

    func focus() async throws -> NSTextView {
        try await settle()
        let tf = try #require(findTextField(window.contentView))
        window.makeFirstResponder(tf)
        try await settle()
        return try #require(tf.currentEditor() as? NSTextView)
    }

    func enter(_ text: String) async throws {
        let tf = try #require(findTextField(window.contentView))
        window.makeFirstResponder(tf)
        try await settle()
        if let editor = tf.currentEditor() as? NSTextView {
            editor.insertText(text, replacementRange: editor.selectedRange())
        } else {
            tf.stringValue += text
            draft.text = tf.stringValue
        }
        try await settle()
    }

    func pressReturn(modifiers: NSEvent.ModifierFlags = []) async throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        if modifiers.contains(.command) { #expect(window.performKeyEquivalent(with: event)) }
        else { window.sendEvent(event) }
        try await settle()
    }

    func click(_ identifier: String) async throws {
        let point = try NativeSyntaxUI.center(identifier, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            window.sendEvent(try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1)))
        }
        try await settle()
    }

    func postModifiers(_ flags: NSEvent.ModifierFlags) async throws {
        let event = try #require(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 55))
        NSApp.postEvent(event, atStart: true)
        try await settle()
        try await Task.sleep(for: .milliseconds(350))
    }

    func buttonPixels() throws -> Data {
        let view = try #require(window.contentView)
        let rect = view.convert(try NativeSyntaxUI.frame("syntax.commandReturn.button", in: window), from: nil)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: rect))
        view.cacheDisplay(in: rect, to: bitmap)
        return Data(bytes: try #require(bitmap.bitmapData), count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-UI-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }
}

private struct ComposerProbeView: View {
    @Bindable var probe: DiaryComposerProbe

    var body: some View {
        DiaryQuickComposerView(text: $probe.text, focused: $probe.focused,
            orderedTags: [], selectedTagIDs: $probe.tagIDs, onSubmit: probe.submit,
            isCompact: true, status: probe.status, onOpenWindow: probe.popout)
    }
}
