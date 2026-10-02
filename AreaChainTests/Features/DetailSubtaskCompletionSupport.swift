import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 同一真实行/详情宿主用于迁移前后对照，不重建视图来模拟回滚刷新。
@MainActor
final class DetailCompletionFixture {
    typealias Native = SettingsButtonTestSupport
    let native: SettingsButtonTestSupport
    let todo: TodoItem
    let subtasks: [SubtaskItem]
    var toggles: [UUID] = []
    var titles: [String] = []
    var deletes = 0
    var reorders = 0
    var rejectToggle = false
    var rejectTitle = false

    init(longTitle: Bool = false) throws {
        native = try Native()
        let parent = TodoItem(title: "合成父项", dayKey: "2026-10-01")
        todo = parent
        subtasks = ["合成子项 / Synthetic subtask", longTitle ? String(repeating: "长标题 / Long title ", count: 8) : "第二子项"]
            .enumerated().map { SubtaskItem(title: $0.element, sortOrder: $0.offset, todo: parent) }
        native.container.mainContext.insert(parent)
        subtasks.forEach { native.container.mainContext.insert($0) }
        try native.container.mainContext.save()
    }

    func row(disabled: Bool = false) -> some View {
        SubtaskRowView(subtask: subtasks[0], siblingIDs: subtasks.map(\.id), onToggle: {
            self.toggles.append(self.subtasks[0].id)
            if !self.rejectToggle { DayBoardMutations.toggleSubtask(self.subtasks[0]) }
        }, onUpdateTitle: { title in
            self.titles.append(title)
            return ModelChanges.perform(in: self.native.container.mainContext, save: { context in
                if self.rejectTitle { throw CocoaError(.fileWriteNoPermission) }
                try context.save()
            }) { DayBoardMutations.editSubtask(self.subtasks[0], title: title) }
        }, onDelete: { self.deletes += 1 }, onReorder: { _ in self.reorders += 1; return true })
            .disabled(disabled)
            .padding(12)
            .background(DaybookPalette.fill.page)
            .syntaxOverlayHost()
    }

    func detail() -> some View {
        TaskDetailSubtasksView(todo: todo).padding(12).background(DaybookPalette.fill.page).syntaxOverlayHost()
    }

    static func completionButtons(in window: NSWindow) throws -> [NSObject] {
        // 原按钮没有稳定标识：按详情左侧完成列定位，同一定位用于迁移前后。
        try Native.buttons(in: window).filter {
            let rect = try Native.frame($0, in: window)
            return rect.minX < 35 && rect.width < 22
        }.sorted { try Native.frame($0, in: window).midY > Native.frame($1, in: window).midY }
    }

    static func fields(in window: NSWindow) -> [NSTextField] {
        Native.elements(window.contentView).compactMap { $0 as? NSTextField }.filter(\.isEditable)
    }

    static func mouse(_ point: NSPoint, in window: NSWindow, count: Int = 1) async throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: count, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
    }

    static func beginEditing(in window: NSWindow, draft: String) async throws {
        let button = try #require(completionButtons(in: window).first)
        let rect = try Native.frame(button, in: window)
        for count in 1...2 { try await mouse(NSPoint(x: 120, y: rect.midY), in: window, count: count) }
        let field = try #require(fields(in: window).first)
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText(draft, replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
    }

    static func pixels(_ window: NSWindow) throws -> Data {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    static func strings(in window: NSWindow) -> [String] {
        Native.elements(window.contentView).flatMap { node in
            ["accessibilityLabel", "accessibilityValue", "accessibilityTitle"].compactMap { Native.value(node, $0) as? String }
        }
    }
}
