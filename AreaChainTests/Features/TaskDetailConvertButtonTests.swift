import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// TaskDetailSections 的两个转换按钮在共享入口抽取后仍走原签名，并打开新对象；合成内存库，测试进程不刷新真实日历。
@Suite(.serialized) @MainActor struct TaskDetailConvertButtonTests {
    @Test(arguments: [false, true]) func detailButtonConvertsAndInspectsNewObject(routine: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 480)
        defer { fixture.cleanup() }
        let window = DetailTimeSupport.window(fixture, routine: routine, width: 360)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try SettingsButtonTestSupport.button(routine ? "drawer.convert.toTodo" : "drawer.convert.toRoutine", in: window)
        try await SettingsButtonTestSupport.reveal(button, in: window)
        try await SettingsButtonTestSupport.click(button, in: window)
        let context = fixture.native.container.mainContext
        let selected = try #require(WorkspaceNavigation.shared.selectedTaskID)
        if routine {
            let created = try #require(try context.fetch(FetchDescriptor<TodoItem>()).first { $0.id == selected })
            #expect(fixture.routine.deletedAt != nil && created.title == fixture.routine.title && created.remindMinutes == 480)
            #expect(created.dayKey == DayKey.today() && created.deletedAt == nil && selected != fixture.routine.id)
        } else {
            let created = try #require(try context.fetch(FetchDescriptor<DailyRoutine>()).first { $0.id == selected })
            #expect(fixture.todo.deletedAt != nil && created.title == fixture.todo.title && created.remindMinutes == 480)
            #expect(created.weekdayMask == ItemConversion.weekdayMask(for: fixture.todo.dayKey) && selected != fixture.todo.id)
        }
        #expect(WorkspaceNavigation.shared.isInspectorPresented)
    }
}
