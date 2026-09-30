import Foundation
import Testing
@testable import AreaChain

struct CompletionUndoNoticeTests {
    private let zh = Locale(identifier: "zh-Hans")
    private let en = Locale(identifier: "en")

    @Test func reopenedTodoNamesTheItem() {
        let notice = CompletionUndoNotice.reopenedTodo(title: "买牛奶", subtasks: 0)
        #expect(notice.text(locale: zh) == "已撤销完成「买牛奶」")
        #expect(notice.text(locale: en) == "Undid completion of “买牛奶”")
    }

    @Test func reopenedTodoCountsRestoredSubtasks() {
        let notice = CompletionUndoNotice.reopenedTodo(title: "买牛奶", subtasks: 2)
        #expect(notice.text(locale: zh) == "已撤销完成「买牛奶」，并重新打开 2 个子任务")
        #expect(notice.text(locale: en) == "Undid completion of “买牛奶” and reopened 2 subtasks")
    }

    @Test func recompletedTodoSaysItIsDoneAgain() {
        let notice = CompletionUndoNotice.recompletedTodo(title: "买牛奶")
        #expect(notice.text(locale: zh) == "已重新标为完成「买牛奶」")
        #expect(notice.text(locale: en) == "Marked “买牛奶” complete again")
    }

    @Test func routineUndoNamesCheckInDirection() {
        #expect(CompletionUndoNotice.reopenedRoutine(title: "喝水").text(locale: zh) == "已撤销打卡「喝水」")
        #expect(CompletionUndoNotice.restoredRoutine(title: "喝水").text(locale: en) == "Restored the check-in for “喝水”")
    }

    @Test func subtaskUndoNamesTheSubtask() {
        #expect(CompletionUndoNotice.reopenedSubtask(title: "盖子").text(locale: zh) == "已撤销完成子任务「盖子」")
        #expect(CompletionUndoNotice.recompletedSubtask(title: "盖子").text(locale: en) == "Marked subtask “盖子” complete again")
    }
}
