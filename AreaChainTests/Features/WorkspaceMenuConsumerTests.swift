import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceMenuConsumerTests {
    private typealias Native = SettingsButtonTestSupport
    private typealias Menus = MenuButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func threeListingEntrancesKeepIndependentFilters(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        let restore = Menus.preserveListingNavigation()
        defer { restore(); fixture.cleanup() }
        let nav = WorkspaceNavigation.shared
        let context = fixture.container.mainContext
        let todo = TodoItem(title: "Synthetic completed todo", isDone: true, dayKey: DayClock.shared.todayKey)
        let routine = DailyRoutine(title: "Synthetic disabled routine", sortOrder: 0, isEnabled: false,
                                   createdDayKey: DayClock.shared.todayKey)
        context.insert(todo)
        context.insert(routine)
        try context.save()
        nav.allItemsQuery = ItemsListingQuery(todayKey: DayClock.shared.todayKey)
        let window = fixture.window(WorkspaceAllItemsView(), locale: locale, scheme: scheme,
                                    size: NSSize(width: 480, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let initial = nav.allItemsQuery
        nav.selectedTaskIDs = [todo.id]
        nav.selectedTaskID = todo.id
        nav.isInspectorPresented = true
        let nodes = Array(Menus.menus(in: window).prefix(3))
        #expect(nodes.count == 3)
        try Native.assertBounds(nodes, in: window)
        for node in nodes {
            try Menus.assertTextWidth(node, in: window)
            _ = try await Menus.openAndEscape(node, xFraction: 0.04, in: window)
            _ = try await Menus.openAndEscape(node, xFraction: 0.7, in: window)
            #expect(nav.allItemsQuery == initial)
            #expect(nav.selectedTaskIDs == [todo.id] && nav.selectedTaskID == todo.id && nav.isInspectorPresented)
        }
        try await choose(0, key: "items.kind.recurring", locale: locale, window: window)
        #expect(nav.allItemsQuery.kind == .recurring)
        #expect(nav.allItemsQuery.todoStatus == .all && nav.allItemsQuery.routineStatus == .all)
        try await choose(1, key: "items.status.done", locale: locale, window: window)
        #expect(nav.allItemsQuery.kind == .recurring && nav.allItemsQuery.todoStatus == .done)
        #expect(nav.allItemsQuery.routineStatus == .all)
        try await choose(2, key: "items.status.disabled", locale: locale, window: window)
        #expect(nav.allItemsQuery.kind == .recurring && nav.allItemsQuery.todoStatus == .done)
        #expect(nav.allItemsQuery.routineStatus == .disabled && nav.allItemsQuery.filter == initial.filter)
        let expected = ["items.kind.recurring", "items.status.done", "items.status.disabled"]
        let current = Array(Menus.menus(in: window).prefix(3))
        #expect(current.map(Menus.title) == expected.map { Menus.localized($0, locale) })
        try Native.assertBounds(current, in: window)
        for node in current { try Menus.assertTextWidth(node, in: window) }
        let model = WorkspaceAllItemsPageModel.make(routines: [routine], todos: [todo], checks: [],
            todayKey: DayClock.shared.todayKey, navigation: nav, locale: Locale(identifier: locale))
        #expect(model.visibleIDs == [routine.id])
        #expect(Menus.labels(in: window).contains(routine.title))
        #expect(!context.hasChanges && todo.isDone && !routine.isEnabled)
        try Native.snapshot(window, name: "all-items-menus-\(locale)-\(scheme)")
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func tagColorAndMergeCancellationUseOriginalSelection(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        let tags = ["common.save", String(repeating: "合成的长标签 Synthetic # & 🏷️ · ", count: 5), "Untouched"]
            .enumerated().map { TagItem(name: $0.element, sortOrder: $0.offset) }
        tags.forEach { context.insert($0) }
        let todo = TodoItem(title: "Synthetic tagged todo", dayKey: DayClock.shared.todayKey,
                            tagIDs: tags[0].id.uuidString)
        context.insert(todo)
        try context.save()
        let window = fixture.window(TagManagementPage(), locale: locale, scheme: scheme,
                                    size: NSSize(width: 480, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(Menus.menus(in: window).isEmpty)
        try await selectTagRows(in: window)
        try Native.snapshot(window, name: "tags-selection-\(locale)-\(scheme)")
        let color = try Menus.menu("tags.color", locale: locale, in: window)
        try Menus.assertTextWidth(color, in: window)
        let oldColors = tags.map(\.colorToken)
        let menu = try await Menus.openAndEscape(color, xFraction: 0.04, in: window)
        #expect(tags.map(\.colorToken) == oldColors && !context.hasChanges)
        try Menus.dispatch(Menus.localized("tags.color.clay", locale), in: menu)
        try await SystemPageHost.settle(window)
        #expect(tags[0].colorToken == TagColorToken.clay.rawValue && tags[1].colorToken == TagColorToken.clay.rawValue)
        #expect(tags[2].colorToken == oldColors[2] && !context.hasChanges)
        try Native.snapshot(window, name: "tags-color-\(locale)-\(scheme)")
        let before = tags.map { ($0.id, $0.name, $0.colorToken, $0.deletedAt) }
        let merge = try Native.button("tags.merge", locale: locale, in: window)
        try Native.assertBounds([color, merge], in: window)
        let sheet = try await presentMerge(in: window, locale: locale)
        try assertMergePresentation(in: sheet, locale: locale, tagName: tags[0].name)
        let picker = try Menus.menu("tags.merge.pickTarget", locale: locale, in: sheet)
        let targets = try await Menus.openAndEscape(picker, in: sheet)
        #expect(targets.items.map(\.title) == tags.prefix(2).map(\.name))
        #expect(targets.items.map(\.state) == [.on, .off])
        try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: sheet)
        try assertMergePresentation(in: sheet, locale: locale, tagName: tags[1].name)
        #expect(targets.items.map(\.state) == [.off, .on])
        _ = try await Menus.openAndEscape(picker, in: sheet)
        #expect(window.attachedSheet === sheet && !context.hasChanges)
        #expect(todo.tagIDs == tags[0].id.uuidString && tags.allSatisfy { $0.deletedAt == nil })
        try Native.snapshot(sheet, name: "tags-merge-locale-\(locale)-\(scheme)")
        try await cancelMerge(sheet, from: window, locale: locale)
        try await NativeSyntaxUI.prepareFocus(in: window)
        let reopened = try await presentMerge(in: window, locale: locale)
        try assertMergePresentation(in: reopened, locale: locale, tagName: tags[0].name)
        try await cancelMerge(reopened, from: window, locale: locale)
        for (tag, original) in zip(tags, before) {
            #expect(tag.id == original.0 && tag.name == original.1 && tag.colorToken == original.2 && tag.deletedAt == original.3)
        }
        #expect(todo.tagIDs == tags[0].id.uuidString && !context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 3)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func reopenedMergeUsesChangedHostLanguage(scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        let tags = ["common.save", "中文 English # & 🏷️", "Untouched"]
            .enumerated().map { TagItem(name: $0.element, sortOrder: $0.offset) }
        tags.forEach { context.insert($0) }
        try context.save()
        let language = MergeTestLanguage()
        let window = fixture.window(MergeLanguageHost(language: language), scheme: scheme,
                                    size: NSSize(width: 480, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await selectTagRows(in: window)
        let names = tags.map(\.name)
        for locale in ["en", "zh-Hans", "en"] {
            // 只改测试视图环境，不重建页面或改全局语言偏好；原选择必须跨语言保留。
            language.identifier = locale
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let sheet = try await presentMerge(in: window, locale: locale)
            try assertMergePresentation(in: sheet, locale: locale, tagName: names[0])
            let picker = try Menus.menu("tags.merge.pickTarget", locale: locale, in: sheet)
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: sheet)
            let changedLocale = locale == "en" ? "zh-Hans" : "en"
            language.identifier = changedLocale
            try await SystemPageHost.settle(sheet)
            try assertMergePresentation(in: sheet, locale: changedLocale, tagName: names[1])
            let changed = try Menus.menu("tags.merge.pickTarget", locale: changedLocale, in: sheet)
            let menu = try await Menus.openAndEscape(changed, in: sheet)
            #expect(menu.items.map(\.title) == Array(names.prefix(2)))
            #expect(menu.items.map(\.state) == [.off, .on])
            try await cancelMerge(sheet, from: window, locale: changedLocale)
            #expect(tags.map(\.name) == names && tags.allSatisfy { $0.deletedAt == nil })
            #expect(!context.hasChanges)
        }
    }

    private func presentMerge(in window: NSWindow, locale: String) async throws -> NSWindow {
        let merge = try Native.button("tags.merge", locale: locale, in: window)
        try await Native.click(merge, in: window)
        let sheet = try #require(window.attachedSheet)
        try await NativeSyntaxUI.prepareFocus(in: sheet)
        // 原生 sheet 的过渡不受宿主禁动画控制，等几何连续稳定后再读辅助树。
        var previousFrame = sheet.frame
        var stable = 0
        for _ in 0..<20 where stable < 3 {
            try await Task.sleep(for: .milliseconds(100))
            stable = sheet.frame == previousFrame ? stable + 1 : 0
            previousFrame = sheet.frame
        }
        try #require(stable == 3 && sheet.isKeyWindow)
        return sheet
    }

    private func assertMergePresentation(in sheet: NSWindow, locale: String, tagName: String) throws {
        let elements = Native.elements(sheet.contentView)
        let keys = ["tags.merge.confirm.title", "tags.merge.confirm.message"]
        let textNodes = try keys.map { key in
            let expected = Menus.localized(key, locale)
            return try #require(elements.first { node in
                ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
                    Native.value(node, $0) as? String == expected
                }
            }, "合并弹窗必须显示目标语言文案：\(key) / \(locale)")
        }
        let expectedCancel = Menus.localized("alert.cancel", locale)
        let usesRequestedLanguage = Native.buttons(in: sheet).contains { Menus.title($0) == expectedCancel }
        #expect(usesRequestedLanguage, "mergeSheet 必须继承宿主语言，不能回退英文")
        let cancel = try Native.button("alert.cancel", locale: locale, in: sheet)
        let confirm = try Native.button("tags.merge", locale: locale, in: sheet)
        #expect(Menus.title(confirm) == Menus.localized("tags.merge", locale))
        // 公共控件的字段名由菜单自身提供；不能把同一个辅助节点当成相邻文本重复验几何。
        let picker = try Menus.menu("tags.merge.pickTarget", locale: locale, in: sheet)
        let value = try #require(Native.value(picker, "accessibilityValue") as? String)
        #expect(Array(value.utf8) == Array(tagName.utf8))
        #expect(try #require(sheet.contentView).bounds.width == 360)
        try Native.assertBounds(textNodes + [picker, cancel, confirm], in: sheet)
        #expect(abs(try Native.frame(cancel, in: sheet).height - Native.frame(confirm, in: sheet).height) < 1)
    }

    private func cancelMerge(_ sheet: NSWindow, from window: NSWindow, locale: String) async throws {
        let cancel = try Native.button("alert.cancel", locale: locale, in: sheet)
        try await Native.click(cancel, in: sheet)
        for _ in 0..<30 where window.attachedSheet != nil { try await Task.sleep(for: .milliseconds(50)) }
        #expect(window.attachedSheet == nil)
    }

    private func choose(_ index: Int, key: String, locale: String, window: NSWindow) async throws {
        let node = try #require(Menus.menus(in: window).dropFirst(index).first)
        let menu = try await Menus.openAndEscape(node, in: window)
        try Menus.dispatch(Menus.localized(key, locale), in: menu)
        try await SystemPageHost.settle(window)
    }

    private func selectTagRows(in window: NSWindow) async throws {
        let table = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTableView }.first)
        #expect(table.numberOfRows == 3)
        // 通过真实 List 的 NSTableView 选择建立夹具，不复制页面的 selection 或业务回调。
        table.selectRowIndexes(IndexSet([0, 1]), byExtendingSelection: false)
        try await SystemPageHost.settle(window)
        #expect(table.selectedRowIndexes == IndexSet([0, 1]))
    }

    @Test func mergeCommitsChosenUUIDThroughOriginalMemoryRepository() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        #expect(NotificationScheduler.isRunningTests)
        #expect(DayBoardMutations.catalogRepositoryProvider == nil)
        let source = TagItem(name: "common.save", sortOrder: 1)
        let target = TagItem(name: "common.save", sortOrder: 2)
        let preset = TagItem(name: DiaryMemoTags.journal, sortOrder: 0)
        let untouched = TagItem(name: "Untouched", sortOrder: 3)
        let tags = [target, untouched, source, preset]
        let names = tags.map(\.name)
        tags.forEach { context.insert($0) }
        let original = TagIDList.encode([source.id, untouched.id, target.id])
        let todo = TodoItem(title: "Synthetic merge todo", dayKey: "2026-10-02", tagIDs: original)
        let child = SubtaskItem(title: "Synthetic merge child", tagIDs: source.id.uuidString, todo: todo)
        todo.subtasks = [child]
        let routine = DailyRoutine(title: "Synthetic merge routine", sortOrder: 0, tagIDs: source.id.uuidString)
        let diary = DiaryEntry(text: "Synthetic ordinary merge diary", dayKey: "2026-10-02", tagIDs: source.id.uuidString)
        context.insert(todo); context.insert(child); context.insert(routine); context.insert(diary)
        try context.save()
        let window = fixture.window(TagManagementPage(), size: NSSize(width: 480, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let table = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTableView }.first)
        #expect(table.numberOfRows == 4)
        table.selectRowIndexes(IndexSet([0, 1, 2]), byExtendingSelection: false)
        try await SystemPageHost.settle(window)
        let sheet = try await presentMerge(in: window, locale: "en")
        let picker = try Menus.menu("tags.merge.pickTarget", in: sheet)
        let menu = try await Menus.openAndEscape(picker, in: sheet)
        #expect(menu.items.map(\.title) == [source.name, target.name], "预置标签不进入普通合并目标")
        #expect(menu.items.map(\.state) == [.on, .off])
        try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: sheet)
        #expect(menu.items.map(\.state) == [.off, .on])
        #expect(todo.tagIDs == original && !context.hasChanges && tags.allSatisfy { $0.deletedAt == nil })
        try await Native.click(Native.button("tags.merge", in: sheet), in: sheet)
        for _ in 0..<30 where window.attachedSheet != nil { try await Task.sleep(for: .milliseconds(50)) }
        #expect(window.attachedSheet == nil)
        #expect(source.deletedAt != nil && target.deletedAt == nil && preset.deletedAt == nil && untouched.deletedAt == nil)
        #expect(todo.tagIDs == TagIDList.encode([untouched.id, target.id]))
        #expect(child.tagIDs == target.id.uuidString && routine.tagIDs == target.id.uuidString && diary.tagIDs == target.id.uuidString)
        #expect(tags.map(\.name) == names)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 4)
        #expect(!context.hasChanges)
    }
}

@Observable @MainActor
private final class MergeTestLanguage {
    var identifier = "en"
}

private struct MergeLanguageHost: View {
    let language: MergeTestLanguage

    var body: some View {
        TagManagementPage()
            .environment(\.locale, Locale(identifier: language.identifier))
    }
}
