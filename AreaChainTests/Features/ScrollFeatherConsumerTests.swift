import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ScrollFeatherConsumerTests {
    @Test(arguments: ["en", "zh-Hans"])
    func tasksAndDiaryUseTheirListAndKeepContent(locale: String) async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        defer { restore(); fixture.cleanup() }
        let today = DayClock.shared.todayKey
        let todos = (0..<40).map {
            TodoItem(title: "Synthetic task \($0)", dayKey: today, createdAt: .init(timeIntervalSince1970: Double($0)))
        }
        let entries = (0..<40).map {
            DiaryEntry(text: "Synthetic note \($0)", dayKey: today, createdAt: .init(timeIntervalSince1970: Double($0)))
        }
        todos.forEach { fixture.container.mainContext.insert($0) }
        entries.forEach { fixture.container.mainContext.insert($0) }
        try fixture.container.mainContext.save()
        let todoBefore = todos.map(\.snapshot)
        let diaryBefore = entries.map(\.snapshot)
        let tasks = fixture.window(TasksPage(todayKey: today, routines: [], checks: [], todos: todos),
            locale: locale, scheme: locale == "en" ? .light : .dark, size: .init(width: 480, height: 420))
        defer { SystemPageHost.release(tasks) }
        try await verify(tasks, lastID: todos[39].id, label: "tasks-\(locale)")
        var draft = BoardComposerDraft()
        draft.text = "Synthetic unsubmitted draft"
        let originalDraft = draft
        let diary = fixture.window(DiaryPage(todayKey: today, entries: entries, options: .init(
            showsPageHeader: false, composerDraft: Binding(get: { draft }, set: { draft = $0 }))),
            locale: locale, scheme: locale == "en" ? .light : .dark, size: .init(width: 480, height: 420))
        defer { SystemPageHost.release(diary) }
        // Diary 的时间倒序显示，最早条目位于底部；不用固定视口偏移猜测最后一行。
        try await verify(diary, lastID: entries[0].id, label: "diary-\(locale)")
        #expect(todos.map(\.snapshot) == todoBefore && entries.map(\.snapshot) == diaryBefore)
        #expect(draft.id == originalDraft.id && draft.text == originalDraft.text)
        #expect(draft.selectedTagIDs == originalDraft.selectedTagIDs && !draft.needsProtection && draft.sealed == nil)
        #expect(!fixture.container.mainContext.hasChanges)
    }

    private func verify(_ window: NSWindow, lastID: UUID, label: String) async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let nodes = ScrollNativeEvidence.views(window)
        let row = try #require(nodes.compactMap { $0 as? BoardRowPointerView }
            .first { $0.identifier?.rawValue == lastID.uuidString })
        let scroll = try #require(row.enclosingScrollView)
        let edges = nodes.compactMap { $0 as? DaybookScrollEdgeObserverNSView }
        #expect(edges.count == 1)
        let edge = try #require(edges.first)
        #expect(edge.currentScrollView === scroll && edge.scope?.host?.currentScrollView === scroll)
        let size = scroll.bounds.size
        for progress in [0.0, 0.5, 1.0] {
            let maximum = try #require(scroll.documentView).bounds.height - scroll.documentVisibleRect.height
            scroll.contentView.scroll(to: .init(x: 0, y: maximum * progress))
            try await Task.sleep(for: .milliseconds(180))
            #expect(FeatherTestEvidence.state(edge) == [progress > 0, progress < 1])
            #expect(scroll.bounds.size == size && !scroll.hasVerticalScroller)
            print("FEATHER_CONSUMER \(label) p=\(progress) target=\(ScrollNativeEvidence.identity(scroll)) "
                + "visible=\(scroll.documentVisibleRect) state=\(FeatherTestEvidence.state(edge))")
        }
        let rect = row.convert(row.bounds, to: nil)
        let viewport = scroll.contentView.convert(scroll.contentView.bounds, to: nil)
        #expect(viewport.contains(.init(x: rect.midX, y: rect.midY)))
        let point = NSPoint(x: rect.midX, y: rect.midY)
        let root = try #require(window.contentView)
        let hit = root.hitTest(root.superview?.convert(point, from: nil) ?? point)
        #expect(!(hit is DaybookScrollEdgeObserverNSView) && !(hit is DaybookFloatingScrollerOverlay))
        // 单击正文选择；不双击打开窗口，不触发复制、勾选或保存动作。
        try await SurfaceEventTestSupport.click(point, in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "feather-\(label)-bottom")
    }
}
