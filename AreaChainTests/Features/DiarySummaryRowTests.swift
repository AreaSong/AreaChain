import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DiarySummaryRowTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test func diarySummaryRowRendersAssignedTags() async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let context = container.mainContext

        let tag1 = TagItem(name: "日记", sortOrder: 0)
        let tag2 = TagItem(name: "灵感", sortOrder: 1)
        context.insert(tag1)
        context.insert(tag2)
        try context.save()

        let entry = DiaryEntry(
            text: "测试手记内容 #日记 #灵感",
            dayKey: "2026-09-19",
            tagIDs: TagIDList.encode([tag1.id, tag2.id])
        )
        context.insert(entry)
        try context.save()

        let row = DiarySummaryRow(
            entry: entry,
            privacyTags: [tag1, tag2],
            allTags: [tag1, tag2],
            onSelect: {},
            onDelete: {}
        )

        let window = host(row)
        defer { close(window) }
        try await settle(window)

        #expect(row.previewText == "测试手记内容 #日记 #灵感")
    }

    @Test func diarySummaryRowRendersContentAndPinIcon() async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let context = container.mainContext

        let entry = DiaryEntry(text: "置顶手记测试", dayKey: "2026-09-19")
        entry.isPinned = true
        context.insert(entry)
        try context.save()

        let row = DiarySummaryRow(
            entry: entry,
            allTags: [],
            onDelete: {}
        )

        let window = host(row)
        defer { close(window) }
        try await settle(window)

        #expect(row.entry.isPinned)
        #expect(row.previewText == "置顶手记测试")
    }

    @Test func diarySummaryRowSeparatesTitleAndBodyWhenMultiline() async throws {
        let entry = DiaryEntry(text: "灵感标题\n这里是手记的具体正文细节", dayKey: "2026-09-20")
        let row = DiarySummaryRow(entry: entry, onDelete: {})

        #expect(row.contentPresentation.title == "灵感标题")
        #expect(row.contentPresentation.body == "这里是手记的具体正文细节")
    }

    @Test func diarySummaryRowTreatsSingleLineAsBodyWithoutTitle() async throws {
        let entry = DiaryEntry(text: "单行随手记正文内容没有换行", dayKey: "2026-09-20")
        let row = DiarySummaryRow(entry: entry, onDelete: {})

        #expect(row.contentPresentation.title == nil)
        #expect(row.contentPresentation.body == "单行随手记正文内容没有换行")
        #expect(row.contentPresentation.hasMultipleLines == false)
    }

    @Test func diarySummaryRowTruncationCalculation() throws {
        let shortText = "短手记"
        let longText = "这是一段非常非常非常非常非常长的单行手记正文，用于触发截断气泡展示"
        #expect(!RowTitleTruncation.isTruncated(shortText))
        #expect(RowTitleTruncation.isTruncated(longText))
    }

    @Test func diarySummaryRowBubblePlacementCalculation() throws {
        // 顶部位置：向下生长
        let topPlacement = RowBubblePlacement.calculate(globalPoint: CGPoint(x: 50, y: 150), isWorkspace: false)
        #expect(topPlacement.growsUpward == false)
        #expect(topPlacement.bubbleShiftX == 0)

        // 底部偏右位置：向上生长，且向左平移防溢出
        let bottomPlacement = RowBubblePlacement.calculate(globalPoint: CGPoint(x: 250, y: 320), isWorkspace: false)
        #expect(bottomPlacement.growsUpward == true)
        #expect(bottomPlacement.bubbleShiftX < 0)
    }

    @Test func diaryMutationsConvertMoveAndTogglePrivate() async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let context = container.mainContext

        let entry = DiaryEntry(text: "随手记标题\n详细内容备忘", dayKey: "2026-09-18")
        context.insert(entry)
        try context.save()

        // 1. 移动日期
        let moved = DayBoardMutations.moveDiary(entry, to: "2026-09-20")
        #expect(moved)
        #expect(entry.dayKey == "2026-09-20")

        // 2. 切换私密状态
        let toggledPrivate = DayBoardMutations.togglePrivateDiary(entry)
        #expect(toggledPrivate)
        #expect(entry.isPrivate == true)

        // 3. 转为待办
        let converted = DayBoardMutations.convertDiaryToTodo(entry, context: context)
        #expect(converted)

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(todos.contains { $0.title == "随手记标题" && $0.notes == "详细内容备忘" })
    }

    private func host<Content: View>(_ content: Content, size: NSSize = NSSize(width: 380, height: 80)) -> NSWindow {
        NSApp.setActivationPolicy(.regular)
        let hosting = NSHostingView(rootView: content
            .frame(width: size.width, height: size.height)
            .background(DaybookTheme.paper)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
        )
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "AreaChain 手记测试"
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setContentSize(size)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func close(_ window: NSWindow) {
        window.contentView = nil
        window.orderOut(nil)
    }

    private func settle(_ window: NSWindow) async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        window.contentView?.layoutSubtreeIfNeeded()
    }
}
