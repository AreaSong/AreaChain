import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// L-M1b 检查点 C：备注摘要改为协调者随机内存密钥的 HMAC-SHA256（L6）；冲突基线与未知核对的三摘要规则。
@Suite(.serialized) @MainActor struct LongTextDigestTests {
    /// 同一协调者同文同摘要；换协调者（换密钥）同文不同摘要；都不是可被字典猜出的纯 SHA-256。
    @Test func notesDigestIsKeyedPerCoordinator() throws {
        let f = try TaskSimpleFixture(longText: true)
        let g = try TaskSimpleFixture(longText: true)
        let short = "好"
        let first = TaskCommandSpecs.notesField(short, f.dependencies.digest)
        let again = TaskCommandSpecs.notesField(short, f.handoff.coordinator.textDigest)
        let other = TaskCommandSpecs.notesField(short, g.dependencies.digest)
        let plain = SHA256.hash(data: Data(short.utf8)).map { String(format: "%02x", $0) }.joined()
        #expect(first == again && first.value.count == 64 && first.value != other.value && first.value != plain)
        #expect(first.display == .count("unified.simple.value.characters", 1))
        #expect(TaskCommandSpecs.notesField("", f.dependencies.digest).display == .localized("unified.simple.value.none"))
        #expect(String(describing: f.dependencies.digest) == "CommandTextDigest(redacted)")
    }

    /// replace 记目标备注与派生字段；append、clear 都带旧备注摘要：接受后备注被别处改动，提交报冲突、不写。
    @Test(arguments: [CommandFieldOperation.replace, .append, .clear])
    func baselineCarriesOldNotesForEveryOperation(_ operation: CommandFieldOperation) throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "基线", dayKey: TaskSimpleFixture.today, notes: "旧备注"))
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)],
                    arguments: [f.notes(operation, operation == .clear ? nil : "新内容")])
        let accepted = try f.accept()
        let row = try #require(accepted.preview.before.rows.first { $0.key == todo.id.uuidString })
        #expect(row.fields.map(\.id) == ["notes", "tags", "remind", "priority"])
        #expect(row.fields.first?.value == f.dependencies.digest.hex("旧备注"))
        // 别处只改备注（标签、提醒、优先级都不变）：只有备注摘要能发现。
        todo.notes = "别处改过"
        try f.context.save()
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try f.submit(accepted) }
        #expect(todo.notes == "别处改过" && f.count("save") == 0)
        // 派生字段同样参与：改回备注、只改优先级也报冲突。
        let g = try TaskSimpleFixture(longText: true)
        let other = try g.insert(TodoItem(title: "派生", dayKey: TaskSimpleFixture.today, notes: "旧备注"))
        try g.queue("todo.notes", targets: [.init(type: .todo, id: other.id)],
                    arguments: [g.notes(operation, operation == .clear ? nil : "新内容")])
        let derived = try g.accept()
        other.isImportant = true
        try g.context.save()
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try g.submit(derived) }
    }

    /// 封存后再被改动：执行前按冻结行重读、比带键摘要，记为未提交并标冲突，不借出正文。
    @Test func sealedRunDetectsConflictBeforeLending() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "封存后冲突", dayKey: TaskSimpleFixture.today, notes: "旧"))
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.append, "追加")])
        let accepted = try f.accept()
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        todo.notes = "旧（别处改过）"
        try f.context.save()
        let run = try f.execution()
        guard case .attempt(let attempt) = try f.handoff.send(.beginStep(run.stamp)) else { throw CommandExecutionError.stale }
        let operation = try #require(run.operation(accepted.preview.item.id))
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) {
            try f.adapter.execute(.init(lease: f.handoff.owned().lease, operation: operation, attempt: attempt))
        }
        let facts = try #require(f.execution().units.first?.simple)
        #expect(facts.state == .notSubmitted && facts.conflict && todo.notes == "旧（别处改过）")
        #expect(f.escrow.state(accepted.preview.handles[.notes]!) == .held)
    }

    /// 未知核对比较写前、期望最终全文与当前三个摘要：等于期望为已写入，等于写前为未写入，其余为冲突；
    /// 当前值不把原 unknown 回执提升为成功，冲突时也不解除阻止。
    @Test func unknownVerificationComparesThreeDigests() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "三摘要", dayKey: TaskSimpleFixture.today, notes: "写前"))
        f.saveMode = .throwAfter
        let (accepted, facts) = try f.run("todo.notes", targets: [.init(type: .todo, id: todo.id)],
                                          arguments: [f.notes(.append, "期望")])
        #expect(facts.state == .unknown)
        let key = f.dependencies.digest
        let fields = { (state: CommandSimpleState) in state.rows.first { $0.key == todo.id.uuidString }?.fields.first?.value }
        #expect(fields(facts.before) == key.hex("写前") && fields(facts.after) == key.hex("写前\n期望"))
        f.saveMode = .normal
        let stored = try #require(try ModelContext(f.io.container).fetch(FetchDescriptor<TodoItem>()).first { $0.id == todo.id })
        stored.notes = "第三方"
        try stored.modelContext?.save()
        let verification = try f.verify()
        #expect(verification.outcome == .inconsistent && verification.acceptanceID == accepted.id)
        #expect(try f.execution().units.first?.simple?.state == .unknown)
        #expect(throws: CommandSimpleIssue.verificationRequired) { try f.handoff.coordinator.simples.requireResolved(accepted.preview.lockKeys) }
        #expect(f.escrow.state(accepted.preview.handles[.notes]!) == .awaitingVerification)
    }
}
