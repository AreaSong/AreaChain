import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 哨兵正文只在宿主草稿、托管与借用里；预览、接受、Snapshot、Run 输入、Facts、回执、
/// 描述与追踪里一处都搜不到（深度反射，含私有存储）。正对照：同一搜索能在草稿与落库结果里找到哨兵。
@Suite(.serialized) @MainActor struct LongTextLoanExportTests {
    static let sentinel = "SENTINEL-长文哨兵-7f3a9c"

    /// 深度反射加两种描述：Mirror 会进入私有存储，比 description 更严。
    static func surfaces(_ values: [Any]) -> String {
        values.map { value in
            var out = ""
            dump(value, to: &out, maxDepth: 64)
            return out + String(describing: value) + String(reflecting: value)
        }.joined(separator: "\n")
    }

    static func exported(_ f: TaskSimpleFixture, _ accepted: CommandSimpleAcceptance, _ facts: CommandSimpleFacts) throws -> String {
        let run = try f.execution()
        let item = try #require(run.snapshot.items.first)
        return surfaces([accepted.preview, accepted, facts, run, run.snapshot, run.resolvedInput(item.id) as Any,
                         try f.handoff.state(), f.handoff.coordinator.simples.acceptances, f.escrow, f.io.trace,
                         accepted.preview.before.changes(to: accepted.preview.after), run.units])
    }

    @Test(arguments: [CommandFieldOperation.replace, .append])
    func notesSentinelStaysInsideDraftEscrowAndLoan(_ operation: CommandFieldOperation) throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "哨兵", dayKey: TaskSimpleFixture.today, notes: "原备注"))
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(operation, Self.sentinel)])
        // 正对照：封存前正文在宿主草稿里，同一搜索能找到。
        #expect(try Self.surfaces([try f.handoff.state()]).contains(Self.sentinel))
        let accepted = try f.accept()
        #expect(!Self.surfaces([accepted, f.handoff.coordinator.simples.acceptances]).contains(Self.sentinel))
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        // 封存后正文只在托管里：宿主会话（含 Snapshot）搜不到。
        #expect(try !Self.surfaces([try f.handoff.state()]).contains(Self.sentinel))
        #expect(Self.surfaces([f.escrow]).contains(Self.sentinel) && String(describing: f.escrow) == "CommandLongTextEscrow(redacted)")
        let run = try f.execution()
        guard case .attempt(let attempt) = try f.handoff.send(.beginStep(run.stamp)) else { throw CommandExecutionError.stale }
        let operationID = try #require(run.operation(accepted.preview.item.id))
        let facts = try f.adapter.execute(.init(lease: f.handoff.owned().lease, operation: operationID, attempt: attempt))
        #expect(facts.state == .saved && todo.notes.contains(Self.sentinel))
        #expect(try !(try Self.exported(f, accepted, facts)).contains(Self.sentinel))
        #expect(f.escrow.count == 0)
    }

    /// 快速新增：标题是派生行（可显示），// 之后的备注部分只以摘要与字数出现。
    @Test func captureSentinelInNotesPartNeverExported() throws {
        let f = try TaskSimpleFixture(longText: true)
        let (accepted, facts) = try f.run("routine.capture", arguments: [f.body("晨读 #普通 // 备注 " + Self.sentinel)])
        #expect(facts.state == .saved)
        let created = try #require(try f.stored(DailyRoutine.self).first { $0.id == facts.creation?.id })
        #expect(created.title == "晨读" && created.notes.contains(Self.sentinel))
        #expect(try !(try Self.exported(f, accepted, facts)).contains(Self.sentinel))
        #expect(accepted.preview.after.rows.first?.fields.first { $0.id == "notes" }?.display == .count("unified.simple.value.characters",
                                                                                                    created.notes.count))
    }

    /// 失败与未知路径同样只留印记；托管在等待归还或核对期间才持有正文。
    @Test func failedAndUnknownFactsStayImprintOnly() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "未知哨兵", dayKey: TaskSimpleFixture.today))
        f.saveMode = .throwAfter
        let (accepted, facts) = try f.run("todo.notes", targets: [.init(type: .todo, id: todo.id)],
                                          arguments: [f.notes(.replace, Self.sentinel)])
        #expect(facts.state == .unknown)
        let run = try f.execution()
        #expect(try !Self.surfaces([accepted, facts, run, try f.handoff.state()]).contains(Self.sentinel))
        let g = try TaskSimpleFixture(longText: true)
        let other = try g.insert(TodoItem(title: "失败哨兵", dayKey: TaskSimpleFixture.today))
        g.tasks = { TaskTM6FailureRepository($0, failOn: 1) }
        let (failedAccepted, failed) = try g.run("todo.notes", targets: [.init(type: .todo, id: other.id)],
                                                 arguments: [g.notes(.replace, Self.sentinel)])
        #expect(try failed.state == .notSubmitted && !Self.surfaces([failedAccepted, failed, try g.execution()]).contains(Self.sentinel))
        try g.returnToDraft()
        #expect(try Self.surfaces([try g.handoff.state()]).contains(Self.sentinel) && g.escrow.count == 0)
    }
}
