import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagDotConsumerTests {
    typealias Dot = TagDotTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionRowsKeepColorsGeometryAndSemantics(locale: String, scheme: ColorScheme) async throws {
        let support = try Dot()
        defer { support.cleanup() }
        for wide in [false, true] {
            for sidebar in [true, false] {
                let window = support.window(sidebar: sidebar, locale: locale, scheme: scheme, wide: wide)
                defer { SystemPageHost.release(window) }
                try await NativeSyntaxUI.prepareFocus(in: window)
                try await SystemPageHost.settle(window)
                try await RowBubbleTestSupport.move(NSPoint(x: 2, y: 2), in: window)
                for token in TagColorToken.allCases.map(\.rawValue) + ["", "unknown"] {
                    // 模拟已支持令牌及旧库原始值；不经会规范化输入的构造器掩盖回退场景。
                    support.tags[0].colorToken = token
                    support.tags[1].colorToken = token
                    try support.context.save()
                    try await SystemPageHost.settle(window)
                    let probe = MenuBarHelpMutationProbe(context: support.context) {
                        for tag in support.tags { _ = tag.name; _ = tag.colorToken; _ = tag.deletedAt }
                    }
                    try await SystemPageHost.settle(window)
                    let name = "\(sidebar ? "sidebar" : "management")-\(wide)-\(locale)-\(scheme)-\(token.isEmpty ? "empty" : token)"
                    try Dot.record(window, name: name)
                    try assertRows(support, sidebar: sidebar, locale: locale, window: window)
                    #expect(probe.writes == 0 && probe.saves == 0 && !support.context.hasChanges)
                }
                if sidebar { WorkspaceNavigation.shared.selectedTagID = support.tags[1].id }
                else { try Dot.table(window).selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false) }
                try await SystemPageHost.settle(window)
                try assertRows(support, sidebar: sidebar, locale: locale, window: window)
                try Dot.record(window, name: "selected-\(sidebar)-\(wide)-\(locale)-\(scheme)")
                WorkspaceNavigation.shared.selectedTagID = nil
            }
        }
    }

    private func assertRows(_ support: Dot, sidebar: Bool, locale: String, window: NSWindow) throws {
        let visible = sidebar ? Array(support.tags.prefix(2)) : support.tags
        for tag in visible { try Dot.assertRow(tag, sidebar: sidebar, locale: locale, in: window) }
        if sidebar {
            let labels = Native.buttons(in: window).map(Dot.text)
            #expect(support.tags.dropFirst(2).allSatisfy { !labels.contains($0.name) }, "侧栏原样排除手记预设分类")
        }
        #expect(try support.context.fetchCount(FetchDescriptor<TagItem>()) == support.tags.count)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func nativeSelectionRenameAndColorEcho(locale: String, scheme: ColorScheme) async throws {
        let support = try Dot()
        defer { support.cleanup() }
        let sidebar = support.window(sidebar: true, locale: locale, scheme: scheme, wide: false)
        let management = support.window(sidebar: false, locale: locale, scheme: scheme, wide: false)
        defer { SystemPageHost.release(sidebar); SystemPageHost.release(management) }
        let probe = MenuBarHelpMutationProbe(context: support.context) {
            for tag in support.tags { _ = tag.name; _ = tag.colorToken; _ = tag.deletedAt }
        }
        try await NativeSyntaxUI.prepareFocus(in: sidebar)
        try await SystemPageHost.settle(sidebar)
        for tag in support.tags.prefix(2) {
            let frame = try Native.frame(Dot.row(tag, sidebar: true, in: sidebar), in: sidebar)
            for x in [frame.minX + 4, frame.minX + 25, frame.maxX - 2] {
                WorkspaceNavigation.shared.selectedTagID = nil
                try await SurfaceEventTestSupport.click(NSPoint(x: x, y: frame.midY), in: sidebar)
                #expect(WorkspaceNavigation.shared.selectedTagID == tag.id)
                #expect(probe.saves == 0 && probe.writes == 0 && !support.context.hasChanges)
            }
            try await RowBubbleTestSupport.move(NSPoint(x: frame.minX + 4, y: frame.midY), in: sidebar)
        }
        try await NativeSyntaxUI.prepareFocus(in: management)
        try await SystemPageHost.settle(management)
        let row = try Native.frame(Dot.row(support.tags[0], sidebar: false, in: management), in: management)
        // NSTableView 的追踪循环直接消费 mouseUp；以实际选择结果验证，不要求外层监视器重复收到释放事件。
        try await Dot.mouse(NSPoint(x: row.minX + 5, y: row.midY), in: management)
        #expect(try Dot.table(management).selectedRowIndexes == IndexSet(integer: 0))
        let selected = try Native.frame(Dot.row(support.tags[0], sidebar: false, in: management), in: management)
        for count in 1...2 {
            try await Dot.mouse(NSPoint(x: selected.minX + 36, y: selected.midY), in: management, count: count)
        }
        let editor = try #require(Native.elements(management.contentView).compactMap { $0 as? DaybookAppKitTextField }
            .first { $0.stringValue == support.tags[0].name })
        #expect(editor.currentEditor() != nil, "双击原标题进入原改名字段")
        try await Native.key(53, in: management)
        #expect(probe.saves == 0 && probe.writes == 0 && !support.context.hasChanges)
        let oldColors = support.tags.map(\.colorToken)
        let beforeSidebar = try support.tags.prefix(2).map { try Dot.color($0, sidebar: true, in: sidebar) }
        let beforeManagement = try support.tags.map { try Dot.color($0, sidebar: false, in: management) }
        #expect(DayBoardMutations.batchSetTagColor(ids: [support.tags[0].id], colorToken: "clay", context: support.context))
        try await SystemPageHost.settle(management)
        try await SystemPageHost.settle(sidebar)
        #expect(probe.saves == 1 && !support.context.hasChanges)
        // SwiftData 查询刷新也会使 Observation 失效；失效次数不能当作存储写入次数。
        #expect(probe.writes >= 1)
        print("TAG_DOT_COLOR saves=\(probe.saves) observations=\(probe.writes)")
        #expect(support.tags.dropFirst().map(\.colorToken) == Array(oldColors.dropFirst()))
        let afterSidebar = try support.tags.prefix(2).map { try Dot.color($0, sidebar: true, in: sidebar) }
        let afterManagement = try support.tags.map { try Dot.color($0, sidebar: false, in: management) }
        #expect(beforeSidebar[0] != afterSidebar[0] && beforeManagement[0] != afterManagement[0])
        #expect(beforeSidebar[1] == afterSidebar[1] && Array(beforeManagement.dropFirst()) == Array(afterManagement.dropFirst()))
        try Dot.assertRow(support.tags[0], sidebar: true, locale: locale, in: sidebar)
        try Dot.assertRow(support.tags[0], sidebar: false, locale: locale, in: management)
        try Dot.record(sidebar, name: "echo-sidebar-\(locale)-\(scheme)")
        try Dot.record(management, name: "echo-management-\(locale)-\(scheme)")
    }
}
