import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsControlsPreviewTests {
    typealias Support = ControlsPreviewTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [false, true])
    func realEntryReuseCloseOrderAndReopen(workspaceFirst: Bool) async throws {
        let support = try Support()
        defer { support.cleanup() }
        let window = try await support.open()
        let content = try #require(window.contentViewController)
        let inputs = FormInputTestSupport.fields(in: window)
        let menus = Native.elements(window.contentView).compactMap { ($0 as? NSPopUpButton)?.menu }
        #expect(window.identifier?.rawValue == "controls.preview.window")
        #expect(window.styleMask.contains(.resizable))
        #expect(try await support.open() === window)
        #expect(NSApp.windows.filter { $0.isVisible && $0.identifier?.rawValue == "controls.preview.window" }.count == 1)
        try await Support.commandReturn(in: window)
        #expect(try Support.actions(in: window) == "1")
        if workspaceFirst {
            support.workspace.close()
            try await SystemPageHost.settle(window)
            #expect(window.isVisible && NSApp.activationPolicy() == .regular)
            window.close()
        } else {
            window.close()
            try await SystemPageHost.settle(support.workspace)
            #expect(support.workspace.isVisible && NSApp.activationPolicy() == .regular)
            support.workspace.close()
        }
        try await SystemPageHost.settle(window)
        #expect(window.contentViewController == nil && window.contentView == nil)
        // 刻意保留 AppKit 容器，验证旧样例已卸载，不能依赖框架何时释放控制器。
        #expect(content.view.window == nil && inputs.allSatisfy { $0.window == nil })
        #expect(menus.flatMap(\.items).allSatisfy { $0.target == nil && $0.action == nil })
        #expect(!Native.elements(content.view).contains { $0 is NSDatePicker || $0 is NSPopUpButton })
        #expect(ControlsPreviewWindowController.shared.hostedWindow == nil)
        #expect(NSApp.activationPolicy() == .accessory)
        let reopened = try await support.open()
        #expect(reopened !== window)
        #expect(try Support.actions(in: reopened) == "0")
        #expect(support.businessEvents == 0 && !support.fixture.container.mainContext.hasChanges)
    }

    @Test func closingPreviewPreservesOtherRegisteredWindows() async throws {
        let support = try Support()
        defer { support.cleanup() }
        let diary = support.fixture.window(Text("Synthetic diary"))
        let clipboard = support.fixture.window(Text("Synthetic clipboard"))
        defer { SystemPageHost.release(diary); SystemPageHost.release(clipboard) }
        AppWindows.diaryWindowsProvider = { [diary] }
        AppWindows.clipboardWindowProvider = { [clipboard] }
        let window = try await support.open()
        window.close()
        try await SystemPageHost.settle(support.workspace)
        #expect(support.workspace.isVisible && diary.isVisible && clipboard.isVisible)
        #expect(NSApp.activationPolicy() == .regular)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func localStatePresentationResetAndSizes(locale: String, dark: Bool) async throws {
        let support = try Support(locale: locale, dark: dark)
        defer { support.cleanup() }
        let baseline = support.fixture.defaults.persistentDomain(forName: support.fixture.suite) ?? [:]
        let window = try await support.open()
        let originalRoot = try #require(window.contentViewController)
        try Support.snapshot(window, name: "settings-preview-initial-\(locale)-\(dark)")
        let label = L10n.string("drawer.tag.create.name", locale: Locale(identifier: locale))
        let field = try #require(FormInputTestSupport.fields(in: window).first { $0.placeholderString == label })
        try await FormInputTestSupport.enter("User sample 原文", into: field, in: window)
        try await Support.press("preview.dark", in: window)
        // 沿原生菜单项 action 更新 locale；不直接改生产私有 @State。
        let language = try MenuButtonTestSupport.menu("dev.controls.language", locale: locale, in: window)
        try await Native.reveal(language, in: window)
        let menu = try await MenuButtonTestSupport.openAndEscape(language, in: window)
        try MenuButtonTestSupport.dispatch(locale == "en" ? "简体中文" : "English", in: menu)
        try await SystemPageHost.settle(window)
        #expect(window.contentViewController === originalRoot)
        #expect(FormInputTestSupport.fields(in: window).contains { $0 === field })
        #expect(field.stringValue == "User sample 原文")
        #expect(window.title == L10n.string("controls.preview.title", locale: Locale(identifier: locale == "en" ? "zh-Hans" : "en")))
        try await Support.press("preview.longLabels", in: window)
        for size in [ControlsPreviewWindowController.contentSize, ControlsPreviewWindowController.minimumContentSize] {
            window.setContentSize(size)
            try await SystemPageHost.settle(window)
            try SystemPageHost.assertContained(["preview.reset", "preview.language", "preview.dark", "preview.disabled",
                                               "preview.longLabels", "syntax.commandReturn.button"], in: window)
            try await Native.reveal(field, in: window)
            try Native.assertBounds([field], in: window)
            try Support.snapshot(window, name: "settings-preview-switched-\(locale)-\(dark)-\(Int(size.width))")
        }
        try await Support.press("preview.disabled", in: window)
        #expect(!field.isEnabled)
        try await Support.commandReturn(in: window)
        #expect(try Support.actions(in: window) == "0")
        try await Support.press("preview.reset", in: window)
        try await Support.press("preview.disabled", in: window)
        #expect(FormInputTestSupport.fields(in: window).contains { $0.stringValue == "" && $0 !== field })
        #expect((support.fixture.defaults.persistentDomain(forName: support.fixture.suite) ?? [:]) as NSDictionary == baseline as NSDictionary)
        #expect(support.businessEvents == 0 && !support.fixture.container.mainContext.hasChanges)
    }
}
