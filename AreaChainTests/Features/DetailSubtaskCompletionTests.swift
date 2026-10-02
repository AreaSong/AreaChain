import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DetailSubtaskCompletionTests {
    private typealias Native = SettingsButtonTestSupport
    private typealias Fixture = DetailCompletionFixture

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func realDetailGeometryAndRoundTrip(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Fixture(longTitle: true)
        defer { fixture.native.cleanup() }
        let window = fixture.native.window(fixture.detail(), locale: locale, scheme: scheme,
                                           size: NSSize(width: 260, height: 310))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let buttons = try Fixture.completionButtons(in: window)
        #expect(buttons.count == 2)
        try Native.assertBounds(buttons, in: window)
        let rect = try Native.frame(buttons[0], in: window)
        #expect(rect.size == NSSize(width: 12, height: 12))
        try Native.snapshot(window, name: "detail-completion-open-\(locale)-\(scheme)")
        try await Native.click(buttons[1], in: window)
        #expect(fixture.subtasks[1].isDone && !fixture.subtasks[0].isDone && !fixture.todo.isDone)
        #expect(Fixture.strings(in: window).contains("1/2"))
        #expect(PendingCompletionManager.shared.pendingDoneIDs.isEmpty)
        #expect(Fixture.fields(in: window).count == 1, "只保留原新增输入，不进入标题编辑")
        try Native.snapshot(window, name: "detail-completion-done-\(locale)-\(scheme)")
        try await Native.click(try Fixture.completionButtons(in: window)[1], in: window)
        #expect(!fixture.subtasks[1].isDone)
        #expect(Fixture.strings(in: window).contains("0/2"))
        let saved = try ModelContext(fixture.native.container).fetch(FetchDescriptor<SubtaskItem>())
        #expect(saved.allSatisfy { !$0.isDone })
        #expect(fixture.subtasks.map(\.sortOrder) == [0, 1])
    }

    @Test func editingCompletionPreservesFocusAndDraft() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        let window = fixture.native.window(fixture.row(), size: NSSize(width: 320, height: 80))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await Fixture.beginEditing(in: window, draft: "未提交标题")
        let responder = window.firstResponder
        try await Native.click(try #require(Fixture.completionButtons(in: window).first), in: window)
        print("DETAIL_FOCUS same=\(window.firstResponder === responder) titles=\(fixture.titles.count) fields=\(Fixture.fields(in: window).count)")
        #expect(window.firstResponder === responder)
        #expect(Fixture.fields(in: window).first?.stringValue == "未提交标题")
        #expect(fixture.titles.isEmpty)
        #expect(fixture.toggles == [fixture.subtasks[0].id])
        #expect(fixture.deletes == 0 && fixture.reorders == 0)
        #expect(fixture.subtasks[0].isDone)
    }

    @Test func rejectedActionAndExternalUpdatesUseTheMountedRow() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        fixture.rejectToggle = true
        let window = fixture.native.window(fixture.row(), size: NSSize(width: 320, height: 80))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await Native.click(try #require(Fixture.completionButtons(in: window).first), in: window)
        let rejected = try Fixture.pixels(window)
        #expect(fixture.toggles.count == 1 && !fixture.subtasks[0].isDone)
        fixture.subtasks[0].isDone = true
        try fixture.native.container.mainContext.save()
        try await SystemPageHost.settle(window)
        #expect(try Fixture.pixels(window) != rejected)
        fixture.subtasks[0].isDone = false
        try fixture.native.container.mainContext.save()
        try await SystemPageHost.settle(window)
        #expect(try Fixture.pixels(window) == rejected)
    }

    @Test func failedTransactionNaturalRefreshCharacterization() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        let window = fixture.native.window(fixture.detail(), size: NSSize(width: 320, height: 180))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let before = try Fixture.pixels(window)
        let button = try #require(Fixture.completionButtons(in: window).first)
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: fixture.native.container.mainContext,
                                         save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                _ = button.perform(NSSelectorFromString("accessibilityPerformPress"))
                #expect(fixture.subtasks[0].isDone, "失败前确实执行了一次完成操作")
            }
        }
        try await Task.sleep(for: .milliseconds(600))
        try await SystemPageHost.settle(window)
        #expect(!fixture.subtasks[0].isDone && !fixture.todo.isDone)
        print("DETAIL_ROLLBACK pixelsEqual=\(try Fixture.pixels(window) == before) count0=\(Fixture.strings(in: window).contains("0/2")) count1=\(Fixture.strings(in: window).contains("1/2"))")
        try Native.snapshot(window, name: "detail-completion-rollback")
        let restoredPixels = try Fixture.pixels(window)
        withKnownIssue("H 前后对照：旧详情事务回滚后未自动刷新，见工程手册第三阶段 H") {
            #expect(restoredPixels == before)
            #expect(Fixture.strings(in: window).contains("0/2"))
        }
        // 只由下一次真实动作恢复一致；没有手动重建/重投影视图。
        try await Native.click(try #require(Fixture.completionButtons(in: window).first), in: window)
        #expect(fixture.subtasks[0].isDone)
        try await Native.click(try #require(Fixture.completionButtons(in: window).first), in: window)
        #expect(!fixture.subtasks[0].isDone)
        #expect(Fixture.strings(in: window).contains("0/2"))
    }

    @Test func hitAreaAndAdjacentTitleStaySeparate() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        fixture.rejectToggle = true
        let window = fixture.native.window(fixture.row(), size: NSSize(width: 320, height: 80))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try #require(Fixture.completionButtons(in: window).first)
        let rect = try Native.frame(button, in: window)
        for x in [rect.minX + 0.5, rect.midX, rect.maxX - 0.5] {
            try await Fixture.mouse(NSPoint(x: x, y: rect.midY), in: window)
        }
        #expect(fixture.toggles.count == 3)
        try await Fixture.mouse(NSPoint(x: rect.maxX + 3, y: rect.midY), in: window)
        #expect(fixture.toggles.count == 3)
        #expect(fixture.deletes == 0 && fixture.reorders == 0 && fixture.titles.isEmpty)
        #expect(Fixture.fields(in: window).isEmpty)
    }

    @Test func completionKeepsTagsDragRegionAndAdjacentActions() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        let tag = TagItem(name: "合成标签", sortOrder: 0)
        fixture.native.container.mainContext.insert(tag)
        fixture.subtasks[0].tagIDs = TagIDList.encode([tag.id])
        try fixture.native.container.mainContext.save()
        let window = fixture.native.window(fixture.row(), size: NSSize(width: 320, height: 110))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let pointer = try #require(Native.elements(window.contentView).compactMap { $0 as? BoardRowPointerView }.first)
        let completion = try #require(Fixture.completionButtons(in: window).first)
        let rect = try Native.frame(completion, in: window)
        #expect(!pointer.convert(pointer.bounds, to: nil).intersects(rect))
        #expect(pointer.dragPayload == "subtask-order:" + fixture.subtasks[0].id.uuidString)
        try await Native.click(completion, in: window)
        #expect(fixture.toggles.count == 1 && fixture.deletes == 0 && fixture.reorders == 0)
        #expect(TagIDList.contains(fixture.subtasks[0].tagIDs, tag.id))
        #expect(Fixture.fields(in: window).isEmpty)
        try Native.assertBounds(Native.buttons(in: window), in: window)
        // 标签点击沿原 DaybookChip，与左侧完成列不相交。
        let chip = try #require(Native.buttons(in: window).first {
            (Native.value($0, "accessibilityLabel") as? String ?? "").contains("#合成标签")
        })
        try await Native.click(chip, in: window)
        withKnownIssue("H 前后对照：原标题覆盖层下的合成标签点击未移除，见工程手册第三阶段 H") {
            #expect(!TagIDList.contains(fixture.subtasks[0].tagIDs, tag.id))
        }
        #expect(fixture.toggles.count == 1 && fixture.deletes == 0 && fixture.reorders == 0)
        _ = chip.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await SystemPageHost.settle(window)
        #expect(!TagIDList.contains(fixture.subtasks[0].tagIDs, tag.id))
        #expect(fixture.toggles.count == 1 && fixture.deletes == 0 && fixture.reorders == 0)
    }

    @Test func detailCountsExcludeDeletedAndKeepSortOrder() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        fixture.subtasks[0].sortOrder = 2
        fixture.subtasks[1].sortOrder = 0
        let deleted = SubtaskItem(title: "合成墓碑", sortOrder: 1, todo: fixture.todo)
        deleted.isDone = true
        deleted.deletedAt = Date()
        fixture.native.container.mainContext.insert(deleted)
        try fixture.native.container.mainContext.save()
        let window = fixture.native.window(fixture.detail(), size: NSSize(width: 320, height: 200))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(Fixture.strings(in: window).contains("0/2"))
        let buttons = try Fixture.completionButtons(in: window)
        #expect(buttons.count == 2)
        try await Native.click(buttons[0], in: window)
        #expect(fixture.subtasks[1].isDone && !fixture.subtasks[0].isDone && deleted.isDone)
        #expect(fixture.subtasks.map(\.sortOrder) == [2, 0])
        #expect(Fixture.strings(in: window).contains("1/2"))
    }

    @Test func tagListAlsoConsumesTheSameSubtaskRow() async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        let tag = TagItem(name: "合成标签清单", sortOrder: 0)
        fixture.native.container.mainContext.insert(tag)
        fixture.subtasks[0].tagIDs = TagIDList.encode([tag.id])
        try fixture.native.container.mainContext.save()
        let window = fixture.native.window(WorkspaceFilteredListView(tag: tag), size: NSSize(width: 480, height: 480))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try Native.button("detail.subtask.complete.\(fixture.subtasks[0].id)", in: window)
        try await Native.click(button, in: window)
        #expect(fixture.subtasks[0].isDone && !fixture.todo.isDone && !fixture.subtasks[1].isDone)
        #expect(PendingCompletionManager.shared.pendingDoneIDs.isEmpty)
    }

    @Test(arguments: [false, true])
    func disabledAndProgrammaticActivation(disabled: Bool) async throws {
        let fixture = try Fixture()
        defer { fixture.native.cleanup() }
        let window = fixture.native.window(fixture.row(disabled: disabled), size: NSSize(width: 320, height: 80))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try #require(Fixture.completionButtons(in: window).first)
        try await Native.click(button, in: window)
        _ = button.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await SystemPageHost.settle(window)
        #expect(fixture.toggles.count == (disabled ? 0 : 2))
        #expect(!fixture.subtasks[0].isDone)
    }
}
