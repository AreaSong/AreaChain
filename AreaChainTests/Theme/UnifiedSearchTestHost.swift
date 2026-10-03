import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Observable @MainActor
final class UnifiedSearchTestModel {
    var buffer: UnifiedSearchBuffer
    var focused = true
    var edits: [UnifiedSearchEdit] = []
    var intents: [UnifiedSearchIntent] = []
    var intentSources: [UnifiedSearchBuffer] = []

    init(host: String = "workspace", text: String = "") {
        buffer = .init(lease: .init(ownership: .init(coordinatorID: UUID(), hostID: host, generation: 0), revision: 0),
                       version: 0, text: text)
    }

    var actions: UnifiedSearchActions {
        .init(edit: apply, accept: apply, focus: { [self] in focused = $0 }, intent: { [self] intent, source in
            guard source == buffer else { return }
            intents.append(intent)
            intentSources.append(source)
        })
    }

    private func apply(_ request: UnifiedSearchEdit) -> UnifiedSearchBuffer? {
        guard request.source == buffer else { return nil }
        edits.append(request)
        replace(request.text)
        return buffer
    }

    func replace(_ text: String, privacy: Bool = false) {
        buffer = .init(lease: .init(ownership: buffer.lease.ownership, revision: buffer.lease.revision + 1),
                       version: buffer.version + 1, text: text,
                       privacyRevision: buffer.privacyRevision + (privacy ? 1 : 0))
    }
}

struct UnifiedSearchTestFixture: View {
    @Bindable var model: UnifiedSearchTestModel
    let layout: UnifiedSearchInputLayout
    var top = false
    var motionDisabled = false
    var results: UnifiedSearchController?
    var operations = false

    var body: some View {
        if let results {
            if operations { UnifiedSearchOperationTestContent(controller: results, layout: layout) }
            else { UnifiedSearchResultsTestContent(controller: results, layout: layout) }
        } else {
        VStack {
            if !top { Spacer() }
            UnifiedSearchInput(buffer: model.buffer, focused: $model.focused, actions: model.actions, layout: layout)
            if top { Spacer() }
            // 下方保留宿主内容区域；没有预览编辑器或伪造结果。
            Color.clear.frame(height: 50)
        }
        .padding(12)
        .background(DaybookPalette.fill.page)
        .unifiedSearchOverlayHost(motionDisabled: motionDisabled)
        }
    }
}

@MainActor
final class UnifiedSearchTestHost {
    let model: UnifiedSearchTestModel
    let window: NSWindow
    private let previousAccessibility = NSApp.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))

    init(layout: UnifiedSearchInputLayout = .standard, width: CGFloat = 600,
         locale: String = "en", dark: Bool = false, top: Bool = false, text: String = "", reduceMotion: Bool = false,
         results: UnifiedSearchController? = nil, operations: Bool = false) {
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        model = UnifiedSearchTestModel(host: layout == .standard ? "workspace" : "menubar", text: text)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 480),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let root = UnifiedSearchTestFixture(model: model, layout: layout, top: top, motionDisabled: reduceMotion, results: results, operations: operations)
            .environment(\.locale, Locale(identifier: locale))
            .preferredColorScheme(dark ? .dark : .light)
        window.contentView = NSHostingView(rootView: root)
        window.setContentSize(NSSize(width: width, height: operations ? 960 : (results == nil ? 480 : 890)))
    }

    func start() async throws {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
        window.makeFirstResponder(try field)
        try await settle()
        #expect(window.firstResponder === (try editor))
        // 场景从末尾插入点开始；AppKit 首次聚焦默认全选，location=0 不请求路径候选。
        let input = try editor
        input.setSelectedRange(NSRange(location: input.string.utf16.count, length: 0))
        try await settle()
    }

    var field: NSTextField {
        get throws {
            try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
                .first { $0.cell is UnifiedSearchFieldCell && !isOperationField($0) })
        }
    }
    private func isOperationField(_ field: NSView) -> Bool {
        var ancestor = field.superview
        while let view = ancestor {
            if view is UnifiedSearchOperationBoundary { return true }
            ancestor = view.superview
        }
        return false
    }

    var editor: NSTextView { get throws { try #require(try field.currentEditor() as? NSTextView) } }
    var state: UnifiedSearchInputState {
        get throws { try #require((try field.delegate as? DaybookTextField.Coordinator)?.parent.unifiedSearch) }
    }
    func settle() async throws { try await SystemPageHost.settle(window) }
    func close() {
        SystemPageHost.release(window)
        NSApp.accessibilitySetValue(previousAccessibility ?? false, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    }

    func key(_ code: UInt16, _ character: String, flags: NSEvent.ModifierFlags = []) async throws {
        try #require(window.isKeyWindow)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
        NSApp.sendEvent(event)
        try await settle()
    }

    func click(_ point: NSPoint) async throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await settle()
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChain-UnifiedSearch-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: name + ".png"))
    }
}
