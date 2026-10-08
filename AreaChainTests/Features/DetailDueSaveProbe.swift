import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 非 Observable 的局部记录器；不参与 SwiftUI 失效，也不替换事务或反馈。
@MainActor
final class DetailDueSaveProbe {
    enum Failure: Error { case syntheticFinalSave }
    let context: ModelContext
    let todo: TodoItem
    let saves: DetailTimeSaveCounter
    let initialFailures: Int
    var fails = true
    var requested: [Int?] = []
    var attempted: [Int?] = []
    var stages: [String] = []
    var publications = 0
    private var observer: NSObjectProtocol?

    init(_ fixture: TimePickerConsumerFixture) {
        context = fixture.native.container.mainContext
        todo = fixture.todo
        saves = DetailTimeSaveCounter(context)
        initialFailures = MutationFeedback.shared.failureCount
        observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.publications += 1
                self?.stages.append("publish")
            }
        }
    }

    func stop() {
        saves.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        print("H_DUE_SAVE " + stages.joined(separator: " -> "))
    }

    func save(_ received: ModelContext) throws {
        #expect(received === context && todo.modelContext === context)
        #expect(ModelChanges.hasActiveTransaction(in: received))
        #expect(requested.count == attempted.count + 1)
        let expected = try #require(requested.last)
        #expect(todo.dueMinutes == expected, "最终保存依赖入口前，原 assignDue 必须已经赋值")
        attempted.append(todo.dueMinutes)
        stages.append("assigned/save:\(String(describing: todo.dueMinutes))")
        if fails {
            stages.append("synthetic-throw")
            throw Failure.syntheticFinalSave
        }
        stages.append("context.save-call")
        try received.save()
        stages.append("context.save-return")
    }

    /// 此函数本身不启动事务；返回断言发生在任何 await / settle / AX 读取之前。
    func dispatch(_ minutes: Int?, action: () throws -> Void) rethrows {
        #expect(!context.hasChanges && !ModelChanges.hasActiveTransaction(in: context))
        requested.append(minutes)
        stages.append("request:\(String(describing: minutes))")
        try action()
        #expect(todo.dueMinutes == (fails ? 600 : minutes))
        #expect(todo.remindMinutes == 720 && todo.dayKey == "2026-10-02")
        #expect(!context.hasChanges && !ModelChanges.hasActiveTransaction(in: context))
        stages.append("synchronous-return:due=\(String(describing: todo.dueMinutes)),failures=\(failures)")
    }

    var failures: Int { MutationFeedback.shared.failureCount - initialFailures }

    func expectCounts(_ requests: [Int?], failures: Int, saves: Int, publications: Int) {
        #expect(requested == requests && attempted == requests)
        #expect(self.failures == failures && self.saves.count == saves && self.publications == publications)
    }

    func window(_ fixture: TimePickerConsumerFixture) -> NSWindow {
        fixture.native.window(TodoScheduleSectionView(todo: todo, saveDue: save).padding(12),
                              size: NSSize(width: 320, height: 540))
    }

    /// 只读展开真实父 body，用于独立的 Void 回调返回诊断；原生验收仍直接挂生产 View。
    static func dueControl(in value: Any, depth: Int = 0) -> TaskDetailDueTime? {
        if let control = value as? TaskDetailDueTime { return control }
        guard depth < 12 else { return nil }
        for child in Mirror(reflecting: value).children {
            if let control = dueControl(in: child.value, depth: depth + 1) { return control }
        }
        return nil
    }
}
