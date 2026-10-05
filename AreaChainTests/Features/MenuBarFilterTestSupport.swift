import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Observable @MainActor
final class MenuBarFilterProbe {
    var filters = BoardFilters()
    var category: FilterCategory = .date
    var mounted = true
    var writes: [BoardFilters] = []
    var dismissals = 0

    var binding: Binding<BoardFilters> {
        Binding(get: { self.filters }, set: { self.filters = $0; self.writes.append($0) })
    }
}

struct MenuBarFilterSample: View {
    @Bindable var probe: MenuBarFilterProbe
    var tab: BoardTab = .tasks
    var tags: [TagItem] = []
    var external = true

    var body: some View {
        ZStack {
            if probe.mounted {
                MenuBarFilterFlyout(tab: tab, filters: probe.binding, tags: tags,
                    tagCounts: Dictionary(uniqueKeysWithValues: tags.enumerated().map { ($0.element.id, $0.offset + 1) }),
                    onDismiss: { probe.dismissals += 1 }, externalCategory: external ? $probe.category : nil)
                    .background(SyntaxViewAnchor("syntax.filter.sample"))
            }
        }.frame(width: 380, height: 260)
    }
}

@MainActor
enum MenuBarFilterTestSupport {
    static func toggleFilterKey(in window: NSWindow) async throws {
        // 与既有 MenuBarHelpKeyboardTests 相同：Shift 的忽略修饰字符为 F，实际字符为 f。
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.command, .shift], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "F",
            isARepeat: false, keyCode: 3))
        NSApp.postEvent(event, atStart: false)
        try await MenuBarHelpSurfaceTests().settledHelp(window)
    }

    static func selectTab(_ tab: BoardTab, locale: String, in window: NSWindow) async throws {
        let help = L10n.string(String.LocalizationValue(tab.helpKey), locale: Locale(identifier: locale))
        let nodes = SettingsButtonTestSupport.buttons(in: window).filter {
            SettingsButtonTestSupport.value($0, "accessibilityHelp") as? String == help
        }
        try #require(nodes.count == 1)
        let node = try #require(nodes.first)
        // 页签只作为场景准备，沿生产辅助动作；筛选按钮和选项仍必须取得原生鼠标证据。
        try DaybookSegmentedControlTests().press(node)
        // 菜单栏有显式 transition；按既有帮助宿主的 450ms 观察窗等旧节点退出。
        try await MenuBarHelpSurfaceTests().settledHelp(window)
        #expect((node.value(forKey: "accessibilitySelected") as? NSNumber)?.boolValue == true)
    }

    static func tags(_ count: Int) -> [TagItem] {
        (0..<count).map { TagItem(name: $0 == 0 ? "Synthetic 合成长标签原文未改 Long tag" : "Synthetic \($0)", sortOrder: $0) }
    }

    static func button(_ title: String, in window: NSWindow, minX: CGFloat = 0, categoryOnly: Bool = false) throws -> NSObject {
        let candidates = try SettingsButtonTestSupport.buttons(in: window).filter { node in
            let matches = ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
                (SettingsButtonTestSupport.value(node, $0) as? String)?.contains(title) == true
            }
            let rect = try SettingsButtonTestSupport.frame(node, in: window)
            return matches && rect.minX >= minX && rect.width > 0
                && (!categoryOnly || (rect.maxX < 125 && rect.minY >= 44))
        }
        try #require(candidates.count == 1, "目标必须唯一：\(title)，实际 \(candidates.count)")
        return try #require(candidates.first)
    }

    static func click(_ title: String, in window: NSWindow, minX: CGFloat = 0, categoryOnly: Bool = false) async throws {
        let rect = try SettingsButtonTestSupport.frame(button(title, in: window, minX: minX, categoryOnly: categoryOnly), in: window)
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window)
    }

    static func record(_ window: NSWindow, name: String) throws {
        let phase = ProcessInfo.processInfo.environment["AREACHAIN_FILTER_PHASE"] ?? "current"
        try OverlaySurfaceTestSupport.record(window, name: "9c-\(phase)-\(name)")
        let frames = try SettingsButtonTestSupport.buttons(in: window).map {
            NSStringFromRect(try SettingsButtonTestSupport.frame($0, in: window))
        }.sorted()
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainSurfaceQA")
        let evidence: [String: Any] = ["buttons": frames, "strings": SurfaceConsumerUI.strings(window).sorted()]
        try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appending(path: "9c-\(phase)-\(name).json"))
        SurfaceEventTestSupport.note("filter \(phase) \(name) buttons=\(frames)")
    }

    static func seed(_ support: SettingsButtonTestSupport) throws -> [TagItem] {
        let tags = tags(12)
        (tags + DiaryMemoTags.presets.enumerated().map { TagItem(name: $0.element, sortOrder: $0.offset + 12) })
            .forEach { support.container.mainContext.insert($0) }
        let today = DayClock.shared.todayKey
        support.container.mainContext.insert(TodoItem(title: "Synthetic existing task", dayKey: today, tagIDs: tags[0].id.uuidString))
        let diary = DiaryEntry(text: "Synthetic existing diary", dayKey: today)
        diary.tagIDs = tags[1].id.uuidString
        support.container.mainContext.insert(diary)
        try support.container.mainContext.save()
        return tags
    }

    static func host(_ support: SettingsButtonTestSupport, composer: BoardComposerSession,
                     filters: BoardFilterSession, toolbar: MenuBarToolbarState,
                     locale: String = "en", scheme: ColorScheme = .light) -> NSWindow {
        support.window(MenuBarPopoverView(toolbar: toolbar, composer: composer, filterSession: filters),
                       locale: locale, scheme: scheme, size: DaybookMetrics.Window.popoverSize)
    }
}
