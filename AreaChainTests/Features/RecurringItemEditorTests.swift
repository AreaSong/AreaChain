import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow))
@MainActor
struct RecurringItemEditorTests {
    /// SwiftUI 视图图异步拆除，其 ModelContext 可能比函数内的容器活得久；容器先释放会让同进程后续
    /// 使用 SwiftData 的测试碰到悬空上下文而 trap（例如紧随其后的 TrashViewModeTests）。与其他宿主一样保活到进程结束。
    private static var retainedContainers: [ModelContainer] = []

    @Test func createCopyExistsInBothLanguages() {
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        let pairs = [
            ("recurring.create.open", "新建重复事项", "New recurring item"),
            ("recurring.create.title", "新建重复事项", "New recurring item"),
            ("recurring.create.title.placeholder", "标题", "Title"),
            ("recurring.create.notes", "备注", "Notes"),
            ("recurring.create.cancel", "取消", "Cancel"),
            ("recurring.create.weekdays.required", "至少选择一天。", "Choose at least one day."),
            ("recurring.create.failed", "没有保存成功，草稿还在。", "Could not save. Your draft is still here."),
            ("workspace.residents.open", "管理重复事项", "Manage recurring items"),
            ("drawer.quadrant.title", "四象限优先级", "Priority"),
            ("drawer.remind.title", "提醒", "Reminder"),
            ("drawer.weekdays.title", "重复星期", "Repeat"),
            ("row.time.set", "设时刻", "Set time"),
            ("residents.enabled", "启用", "Enabled"),
            ("common.save", "保存", "Save"),
        ]
        for (key, chinese, english) in pairs {
            let value = String.LocalizationValue(stringLiteral: key)
            #expect(L10n.string(value, locale: zh) == chinese)
            #expect(L10n.string(value, locale: en) == english)
        }
    }

    @Test(arguments: [
        ("zh-Hans", "标题", "备注", "Title", "Notes"),
        ("en", "Title", "Notes", "标题", "备注"),
    ])
    func editorFieldsFollowAppLanguage(
        code: String, title: String, notes: String, otherTitle: String, otherNotes: String
    ) async throws {
        let labels = try await hostedCopy(RecurringItemEditor(), locale: code)
        #expect(labels.contains(title))
        #expect(labels.contains(notes))
        #expect(!labels.contains(otherTitle))
        #expect(!labels.contains(otherNotes))
    }

    private func hostedCopy<Content: View>(_ content: Content, locale: String) async throws -> [String] {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let host = NSHostingView(rootView: content
            .modelContainer(container)
            .environment(\.locale, Locale(identifier: locale))
            .frame(width: 560, height: 720))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        // 后台轮只排窗不前置，避免盖住用户正在用的窗口。
        if NativeSyntaxUI.inBackgroundSuite { window.orderBack(nil) } else { window.makeKeyAndOrderFront(nil) }
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        host.layoutSubtreeIfNeeded()
        return fieldCopy(in: host)
    }

    private func fieldCopy(in view: NSView) -> [String] {
        var found: [String] = []
        if let placeholder = (view as? NSTextField)?.placeholderString, !placeholder.isEmpty {
            found.append(placeholder)
        }
        if let label = view.accessibilityLabel(), !label.isEmpty {
            found.append(label)
        }
        return found + view.subviews.flatMap { fieldCopy(in: $0) }
    }
}
