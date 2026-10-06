import AppKit
import Observation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DetailTimeFailureDiagnosticTests {
    typealias Detail = DetailTimeSupport
    typealias Diagnostic = DetailTimeDiagnosticSupport

    // 这些探针只刻画读取/事务事实，不作为正常消费者恢复验收。
    @Test(arguments: [false, true], [false, true])
    func parentReadDiagnostic(due: Bool, native: Bool) async throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let trace = DetailTimeTrace()
        let window = Diagnostic.window(fixture, trace: trace)
        defer { SystemPageHost.release(window); trace.emit("read probe due=\(due) native=\(native)") }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let clear = try Detail.button("row.time.clear", due: due, locale: "en", in: window)
        #expect(!ModelChanges.perform(in: fixture.native.container.mainContext,
            save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
            try Detail.press(clear, native: native, in: window)
            trace.events.append("action returned, reads=\(trace.reads)")
            withObservationTracking {
                _ = due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes
            } onChange: {
                MainActor.assumeIsolated { trace.events.append("restoration observation invalidated") }
            }
        })
        try await SystemPageHost.settle(window)
        try trace.record("natural", fixture: fixture, due: due, window: window)
        #expect(!trace.reads.isEmpty)
    }

    @Test func repositoryFailureReturnsFalse() throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let previous = DayBoardMutations.taskRepositoryProvider
        defer { DayBoardMutations.taskRepositoryProvider = previous }
        let repository = DetailTimeFailureRepository(fixture.native.container.mainContext)
        DayBoardMutations.taskRepositoryProvider = { _ in repository }
        repository.fails = true
        #expect(!DayBoardMutations.setRemind(fixture.todo, minutes: nil))
        #expect(fixture.todo.remindMinutes == 720 && repository.calls == [nil] && repository.saveBoundaries == 1)
    }

    @Test(arguments: [false, true])
    func nestedReturnFacts(due: Bool) throws {
        let fixture = try Detail.failureFixture()
        defer { fixture.cleanup() }
        let trace = DetailTimeTrace()
        defer { trace.emit("nested facts due=\(due)") }
        var facts: ModelChanges.CommitFacts?
        var inner: Bool?
        var saves = 0
        let result = ModelChanges.perform(in: fixture.native.container.mainContext, save: { _ in
            saves += 1
            throw CocoaError(.fileWriteNoPermission)
        }) {
            try ModelChanges.transaction(in: fixture.native.container.mainContext, boundary: .init(), observe: { facts = $0 }) {}
            inner = due ? DayBoardMutations.setDue(fixture.todo, minutes: nil)
                : DayBoardMutations.setRemind(fixture.todo, minutes: nil)
            #expect(saves == 0 && inner == true && facts?.phase == .working)
            trace.events.append("inner returned=\(String(describing: inner)) saves=\(saves) phase=\(String(describing: facts?.phase))")
            #expect((due ? fixture.todo.dueMinutes : fixture.todo.remindMinutes) == nil)
        }
        #expect(!result && saves == 1 && inner == true)
        #expect(facts?.phase == .rolledBack && facts?.rollback == .returned)
        trace.events.append("outer returned=\(result) saves=\(saves) phase=\(String(describing: facts?.phase)) rollback=\(String(describing: facts?.rollback))")
        #expect(fixture.todo.remindMinutes == 720 && fixture.todo.dueMinutes == 600)
    }
}
