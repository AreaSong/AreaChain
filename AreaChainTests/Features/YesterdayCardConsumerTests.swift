import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct YesterdayCardConsumerTests {
    @Test(arguments: [false, true], YesterdayCardEnvironment.all)
    func contentMatrixAndTodayChangesKeepOriginalLayoutChoice(centered: Bool, environment: YesterdayCardEnvironment) async throws {
        for count in [0, 3, 24] {
            let fixture = try YesterdayCardFixture(centered: centered, count: count)
            defer { fixture.support.cleanup() }
            _ = try fixture.addYesterdayRoutine()
            fixture.todos.first?.title = String(repeating: "Synthetic long title 合成长标题 ", count: 8)
            try fixture.support.container.mainContext.save()
            let models = fixture.todos.map(\.snapshot)
            let routines = fixture.routines.map(\.snapshot)
            let window = fixture.window(locale: environment.locale, scheme: environment.scheme, width: environment.width)
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await fixture.expand(in: window, locale: environment.locale)
            let labels = MenuButtonTestSupport.labels(in: window)
            let locale = Locale(identifier: environment.locale)
            #expect(labels.contains(L10n.string("stamp.yesterday", locale: locale)))
            #expect(labels.contains(L10n.string("stamp.yesterday.moveAll", locale: locale)) == (count > 0))
            let first = try #require(fixture.rows(in: window).first)
            let scroll = try #require(first.enclosingScrollView)
            if count == 24 {
                let document = try #require(scroll.documentView)
                #expect(document.bounds.height > scroll.contentSize.height)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: document.bounds.maxY - scroll.contentSize.height))
                scroll.reflectScrolledClipView(scroll.contentView)
                try await SystemPageHost.settle(window)
                #expect(scroll.contentView.bounds.origin.y > 1)
            }
            #expect(fixture.todos.map(\.snapshot) == models && fixture.routines.map(\.snapshot) == routines)
            try OverlaySurfaceTestSupport.record(window, name: "yesterday-content-\(centered)-\(count)-\(environment.name)")
            if centered && count == 3 {
                try await verifyLayoutChange(fixture, in: window)
            }
        }
    }

    @Test(arguments: [false, true])
    func emptyYesterdayHasNoCardOrMoveAction(centered: Bool) async throws {
        let fixture = try YesterdayCardFixture(centered: centered, count: 0)
        defer { fixture.support.cleanup() }
        let window = fixture.window()
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let labels = MenuButtonTestSupport.labels(in: window)
        #expect(!labels.contains(L10n.string("stamp.yesterday", locale: Locale(identifier: "en"))))
        #expect(!labels.contains(L10n.string("stamp.yesterday.moveAll", locale: Locale(identifier: "en"))))
        #expect(!fixture.support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true])
    func shellHoverIsStaticWhileOriginalRowHoverStillDraws(centered: Bool) async throws {
        let fixture = try YesterdayCardFixture(centered: centered)
        defer { fixture.support.cleanup() }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        let window = fixture.window()
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await fixture.expand(in: window)
        let models = fixture.todos.map(\.snapshot)
        let todo = try #require(fixture.todos.first)
        let row = try fixture.row(todo.id, in: window)
        let frame = row.convert(row.bounds, to: nil)
        try await RowBubbleTestSupport.move(NSPoint(x: 2, y: 2), in: window)
        try await SystemPageHost.settle(window)
        let before = try RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window))
        // 左侧内边距避开任务行与标题；整图比较仍包含外缘。
        try await RowBubbleTestSupport.move(NSPoint(x: centered ? 7 : 4, y: frame.midY), in: window)
        try await SystemPageHost.settle(window)
        #expect(try before == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window)))
        try await RowBubbleTestSupport.move(NSPoint(x: frame.midX, y: frame.midY), in: window)
        try await SystemPageHost.settle(window)
        #expect(try before != RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window)))
        #expect(fixture.todos.map(\.snapshot) == models && !fixture.support.container.mainContext.hasChanges)
    }

    private func verifyLayoutChange(_ fixture: YesterdayCardFixture, in window: NSWindow) async throws {
        let todo = try #require(fixture.todos.first)
        let before = try fixture.row(todo.id, in: window).convert(fixture.row(todo.id, in: window).bounds, to: nil)
        let yesterdayModels = fixture.todos.map(\.snapshot)
        // 更换传入数据触发原 page 分支；不直接设置 showYesterday 或注入布局选择。
        let today = TodoItem(title: "Synthetic today input", dayKey: fixture.today)
        fixture.todos.append(today)
        try await SystemPageHost.settle(window)
        let normal = try fixture.row(todo.id, in: window).convert(fixture.row(todo.id, in: window).bounds, to: nil)
        #expect(before.minX - normal.minX == 5)
        fixture.todos.removeAll { $0.id == today.id }
        try await SystemPageHost.settle(window)
        let restored = try fixture.row(todo.id, in: window).convert(fixture.row(todo.id, in: window).bounds, to: nil)
        #expect(restored == before)
        #expect(fixture.todos.map(\.snapshot) == yesterdayModels)
        #expect(!fixture.support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true])
    func productionLayoutsExpandThroughOriginalEntry(centered: Bool) async throws {
        for locale in ["en", "zh-Hans"] {
            for scheme in [ColorScheme.light, .dark] {
                for width: CGFloat in [356, 480] {
                    let fixture = try YesterdayCardFixture(centered: centered)
                    defer { fixture.support.cleanup() }
                    let window = fixture.window(locale: locale, scheme: scheme, width: width)
                    defer { SystemPageHost.release(window) }
                    try await NativeSyntaxUI.prepareFocus(in: window)
                    try await SystemPageHost.settle(window)
                    let todo = try #require(fixture.todos.first)
                    #expect(!fixture.rows(in: window).contains { $0.identifier?.rawValue == todo.id.uuidString })
                    try await fixture.expand(in: window, locale: locale)
                    let row = try fixture.row(todo.id, in: window)
                    let frame = row.convert(row.bounds, to: nil)
                    #expect(frame.width > 0 && frame.minX >= 0 && frame.maxX <= width)
                    #expect(todo.dayKey == fixture.yesterday && !todo.isDone)
                    _ = try SettingsButtonTestSupport.button("stamp.yesterday.moveAll", locale: locale, in: window)
                    try OverlaySurfaceTestSupport.record(window, name: "yesterday-\(centered)-\(locale)-\(scheme)-\(Int(width))")
                    print("YESTERDAY_GEOMETRY centered=\(centered) locale=\(locale) scheme=\(scheme) width=\(width) row=\(frame)")
                    try await fixture.expand(in: window, locale: locale)
                    #expect(!fixture.rows(in: window).contains { $0.identifier?.rawValue == todo.id.uuidString })
                    #expect(todo.dayKey == fixture.yesterday && !todo.isDone)
                }
            }
        }
    }
}
