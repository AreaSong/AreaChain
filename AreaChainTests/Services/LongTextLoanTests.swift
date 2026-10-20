import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// L-M1b 检查点 B：托管与一次性借用的反例（合成内存库、私有事件中心、fake 刷新与授权）。
@Suite(.serialized) @MainActor struct LongTextLoanTests {
    /// 一次封存后的现场：已接受的预览、本 attempt 的调用占用。
    struct Sealed {
        let accepted: CommandSimpleAcceptance
        let invocation: CommandRuntimeInvocation
    }

    /// 只经托管封存并开始第一步，不执行；便于在签发与 consume 之间插入锁定等事件。
    static func seal(_ f: TaskSimpleFixture, _ todo: TodoItem, _ argument: CommandArgument) throws -> Sealed {
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [argument])
        let accepted = try f.accept()
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        let run = try f.execution()
        guard case .attempt(let attempt) = try f.handoff.send(.beginStep(run.stamp)) else { throw CommandExecutionError.stale }
        let operation = try #require(run.operation(accepted.preview.item.id))
        let invocation = try f.handoff.coordinator.claimSimple(.init(lease: f.handoff.owned().lease, operation: operation,
                                                                     attempt: attempt))
        return .init(accepted: accepted, invocation: invocation)
    }

    /// 经规格的借用写入（规格再交给 TaskNotesService 的出口）；出口本身只允许托管文件与两份规格引用。
    static func write(_ f: TaskSimpleFixture, _ loan: CommandLongTextLoan, _ todo: TodoItem) throws {
        let spec = try #require(try f.pending("todo.notes") as? any SimpleLongTextCommandSpec)
        let input = f.input([.init(type: .todo, id: todo.id)], [f.notes(loan.operation)])
        try spec.apply(.init(input: input), loan: loan, in: f.context)
    }

    @Test func lockAfterLendFailsWithoutWriting() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "锁定", dayKey: TaskSimpleFixture.today, notes: "原备注"))
        let sealed = try Self.seal(f, todo, f.notes(.replace, "新备注"))
        #expect(throws: CommandLongTextLoanError.revoked) {
            try f.escrow.lend(sealed.invocation, preview: sealed.accepted.preview) { loan in
                f.io.center.post(name: .privacyWillLock, object: nil)
                try Self.write(f, loan, todo)
            }
        }
        #expect(todo.notes == "原备注" && !f.context.hasChanges && f.count("save") == 0)
        #expect(f.escrow.state(sealed.accepted.preview.handles[.notes]!) == .blocked)
    }

    /// 封存后、执行前遮罩：整项转为阻塞，执行报 locked、不写；还回草稿后重新预览再封存才能保存。
    @Test func maskBeforeExecuteBlocksItemUntilReturned() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "遮罩", dayKey: TaskSimpleFixture.today, notes: "原备注"))
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.replace, "遮罩后正文")])
        let accepted = try f.accept()
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        f.io.center.post(name: .privacyMask, object: nil)
        let run = try f.execution()
        guard case .attempt(let attempt) = try f.handoff.send(.beginStep(run.stamp)) else { throw CommandExecutionError.stale }
        let operation = try #require(run.operation(accepted.preview.item.id))
        #expect(throws: CommandSimpleIssue.invalidTarget(.locked)) {
            try f.adapter.execute(.init(lease: f.handoff.owned().lease, operation: operation, attempt: attempt))
        }
        #expect(try f.execution().units.first?.simple?.state == .notSubmitted && todo.notes == "原备注" && f.count("save") == 0)
        try f.returnToDraft()
        let draft = try #require(f.handoff.state().plan.items.first?.draft)
        #expect(draft.arguments.first?.value == .longText("遮罩后正文") && f.escrow.count == 0)
        let facts = try f.submit(f.accept())
        #expect(facts.state == .saved && todo.notes == "遮罩后正文")
    }

    @Test func loanIsSingleUseAndExpires() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "一次", dayKey: TaskSimpleFixture.today))
        let sealed = try Self.seal(f, todo, f.notes(.replace, "一次正文"))
        var escaped: CommandLongTextLoan?
        #expect(throws: CommandLongTextLoanError.consumed) {
            try f.escrow.lend(sealed.invocation, preview: sealed.accepted.preview) { loan in
                escaped = loan
                try Self.write(f, loan, todo)
                try Self.write(f, loan, todo)
            }
        }
        // 骨架外直接调出口时仓储自行保存：第一次 consume 已写入，第二次被拒、没有第二次写入。
        #expect(todo.notes == "一次正文")
        let loan = try #require(escaped)
        #expect(loan.consumed && String(describing: loan) == "CommandLongTextLoan(redacted)")
        #expect(throws: CommandLongTextLoanError.consumed) { try Self.write(f, loan, todo) }
        // 同一 attempt 不再签发；未 consume 就离开的借用作废，事后拿到也取不出正文。
        #expect(throws: CommandLongTextLoanError.alreadyLent) {
            try f.escrow.lend(sealed.invocation, preview: sealed.accepted.preview) { _ in }
        }
        f.escrow.settle(sealed.accepted.preview, .notSubmitted)
        var unused: CommandLongTextLoan?
        #expect(throws: CommandLongTextLoanError.alreadyLent) {
            try f.escrow.lend(sealed.invocation, preview: sealed.accepted.preview) { unused = $0 }
        }
        #expect(unused == nil && todo.notes == "一次正文")
    }

    /// 同一 Run 重试：新 attempt 才能新签；旧 attempt 留下的借用已作废。
    @Test func retryNeedsLoanForNewAttempt() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "重试", dayKey: TaskSimpleFixture.today))
        f.tasks = { TaskTM6FailureRepository($0, failOn: 1) }
        let (accepted, first) = try f.run("todo.notes", targets: [.init(type: .todo, id: todo.id)],
                                          arguments: [f.notes(.replace, "重试正文")])
        #expect(first.state == .notSubmitted && todo.notes.isEmpty)
        f.tasks = { SwiftDataTaskRepository(context: $0) }
        let run = try f.execution()
        let old = try #require(run.attempt(accepted.preview.item.id))
        try f.handoff.send(.retry(old, .safeLocalReplay))
        guard case .attempt(let next) = try f.handoff.send(.beginStep(run.stamp)) else { throw CommandExecutionError.stale }
        #expect(next.number == old.number + 1)
        let operation = try #require(run.operation(accepted.preview.item.id))
        let invocation = try f.handoff.coordinator.claimRuntimeInvocation(operation, attempt: next,
                                                                          expecting: f.handoff.owned().lease)
        try f.escrow.lend(invocation, preview: accepted.preview) { loan in try Self.write(f, loan, todo) }
        #expect(todo.notes == "重试正文")
        #expect(throws: CommandLongTextLoanError.alreadyLent) {
            try f.escrow.lend(invocation, preview: accepted.preview) { _ in }
        }
    }

    /// plan、item、draft、参数／操作、摘要与另一宿主（run、attempt、ownership）任一不同都拒绝。
    @Test func anyIdentityMismatchIsRejected() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "身份", dayKey: TaskSimpleFixture.today))
        let sealed = try Self.seal(f, todo, f.notes(.replace, "身份正文"))
        let preview = sealed.accepted.preview
        let imprint = try #require(preview.input.longTextImprints.first)
        let swapped = { (replacement: CommandLongTextImprint) in
            CommandResolvedInput(arguments: preview.input.arguments.map { argument in
                guard case .longTextImprint? = argument.value else { return argument }
                return .init(parameter: argument.parameter, operation: replacement.operation, value: .longTextImprint(replacement))
            }, targets: preview.input.targets)
        }
        let altered = [
            Self.preview(preview, plan: .init(hostID: preview.plan.hostID, planID: UUID(), revision: preview.plan.revision)),
            Self.preview(preview, item: .init(id: preview.item.id, version: preview.item.version + 1)),
            Self.preview(preview, draft: .init(hostID: preview.draft.hostID, draftID: preview.draft.draftID,
                                               version: preview.draft.version + 1)),
            Self.preview(preview, input: swapped(.init(parameter: .notes, operation: .append, byteCount: imprint.byteCount,
                                                       digest: imprint.digest, escrow: imprint.escrow))),
            Self.preview(preview, input: swapped(.init(parameter: .notes, operation: .replace, byteCount: imprint.byteCount,
                                                       digest: String(repeating: "0", count: 64), escrow: imprint.escrow)))]
        for candidate in altered {
            #expect(throws: CommandLongTextLoanError.mismatch) {
                try f.escrow.lend(sealed.invocation, preview: candidate) { loan in try Self.write(f, loan, todo) }
            }
        }
        // 另一宿主的 Run 与 attempt：用它的调用占用借本宿主的托管被拒。
        let other = try Self.sealOnTarget(f, todo)
        #expect(throws: CommandLongTextLoanError.mismatch) {
            try f.escrow.lend(other, preview: preview) { loan in try Self.write(f, loan, todo) }
        }
        #expect(todo.notes.isEmpty && !f.context.hasChanges && f.escrow.state(imprint.escrow) == .held)
    }

    /// 结果未知后不再签发；核为未写入的正文仍可还回草稿，核为已写入即销毁。
    @Test func unknownStopsLendingUntilVerified() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "未知", dayKey: TaskSimpleFixture.today, notes: "写前"))
        f.saveMode = .throwBefore
        let (accepted, facts) = try f.run("todo.notes", targets: [.init(type: .todo, id: todo.id)],
                                          arguments: [f.notes(.append, "未知追加")])
        #expect(facts.state == .unknown)
        let handle = try #require(accepted.preview.handles[.notes])
        #expect(f.escrow.state(handle) == .awaitingVerification)
        // 核对前不能归还：结果可能已写入。
        #expect(throws: CommandExecutionError.notRetryable) { try f.returnToDraft() }
        f.saveMode = .normal
        #expect(try f.verify().outcome == .notApplied && f.escrow.state(handle) == .awaitingVerification)
        try f.returnToDraft()
        let draft = try #require(f.handoff.state().plan.items.first?.draft)
        #expect(draft.arguments.first?.value == .longText("未知追加") && f.escrow.count == 0)

        let g = try TaskSimpleFixture(longText: true)
        let saved = try g.insert(TodoItem(title: "未知已写", dayKey: TaskSimpleFixture.today))
        g.saveMode = .throwAfter
        let (other, unknown) = try g.run("todo.notes", targets: [.init(type: .todo, id: saved.id)], arguments: [g.notes(.replace, "已写")])
        #expect(unknown.state == .unknown && g.escrow.state(other.preview.handles[.notes]!) == .awaitingVerification)
        #expect(throws: (any Error).self) { try g.returnToDraft() }
        g.saveMode = .normal
        #expect(try g.verify().outcome == .applied && g.escrow.count == 0)
    }

    /// 托管登记为结果未知后，即使仍持有本 attempt 的调用占用，也不再签发。
    @Test func unknownSettlementRefusesLend() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "未知签发", dayKey: TaskSimpleFixture.today))
        let sealed = try Self.seal(f, todo, f.notes(.replace, "未知正文"))
        f.escrow.settle(sealed.accepted.preview, .unknown)
        #expect(throws: CommandLongTextLoanError.awaitingVerification) {
            try f.escrow.lend(sealed.invocation, preview: sealed.accepted.preview) { loan in try Self.write(f, loan, todo) }
        }
        #expect(throws: CommandSimpleIssue.stale) {
            try f.escrow.checkLendable(sealed.invocation, preview: sealed.accepted.preview)
        }
        #expect(todo.notes.isEmpty && f.escrow.state(sealed.accepted.preview.handles[.notes]!) == .awaitingVerification)
    }

    /// 预览后、封存前草稿正文被改：封存报 stale，不建 Run、不进托管。
    @Test func draftEditedAfterPreviewMakesSealStale() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "改稿", dayKey: TaskSimpleFixture.today))
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.replace, "接受时")])
        let accepted = try f.accept()
        let item = try #require(f.handoff.state().plan.items.first)
        try f.handoff.plan(.beginEditing(item.stamp))
        let editing = try #require(f.handoff.state().plan.items.first)
        try f.handoff.plan(.edit(editing.stamp, f.notes(.replace, "改过的")))
        try f.handoff.plan(.endEditing(#require(f.handoff.state().plan.items.first).stamp, .finish))
        #expect(throws: CommandSimpleIssue.stale) {
            try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        }
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(try f.handoff.state().execution == nil && f.escrow.count == 0 && f.count("save") == 0)
    }

    /// 宿主被放弃或强制失效：托管同时销毁；之后执行只见印记，拿不到正文、不写。
    @Test func hostDiscardLeavesNoOrphanEscrow() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "失效", dayKey: TaskSimpleFixture.today))
        let sealed = try Self.seal(f, todo, f.notes(.replace, "失效正文"))
        #expect(f.escrow.count == 1)
        f.escrow.discard(try f.handoff.owned().lease.ownership)
        #expect(f.escrow.count == 0)
        #expect(throws: CommandLongTextLoanError.unavailable) {
            try f.escrow.lend(sealed.invocation, preview: sealed.accepted.preview) { loan in try Self.write(f, loan, todo) }
        }
        #expect(throws: (any Error).self) { try f.returnToDraft() }
        #expect(todo.notes.isEmpty && !f.context.hasChanges)
    }

    /// 不经 discard、Run 被协调者撤走（宿主强制失效的同类情形）：下一次访问或隐私事件即清除，不留孤立条目、借不出。
    @Test func runRemovedWithoutDiscardLeavesNoOrphan() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "撤走", dayKey: TaskSimpleFixture.today))
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.replace, "撤走正文")])
        let accepted = try f.accept()
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        let run = try f.execution()
        try f.handoff.send(.cancelStep(accepted.preview.item.id, run.stamp))
        // 绕过托管直接由协调者撤走 Run：托管里仍挂着该 Run 的条目，直到被清除。
        let item = try #require(run.snapshot.items.first)
        try f.handoff.coordinator.returnLongText(run.stamp, texts: [item.id: [.notes: "撤走正文"]],
                                                 expecting: f.handoff.owned().lease)
        f.io.center.post(name: .privacyDidChange, object: nil)
        #expect(f.escrow.count == 0 && f.escrow.state(accepted.preview.handles[.notes]!) == nil)
        #expect(todo.notes.isEmpty && f.count("save") == 0)
    }

    /// 取消未开始：正文逐字还回草稿（含换行与表情）。
    @Test func cancelNotStartedReturnsTextVerbatim() throws {
        let f = try TaskSimpleFixture(longText: true)
        let todo = try f.insert(TodoItem(title: "取消", dayKey: TaskSimpleFixture.today))
        let text = "第一行\n第二行 🌱 #普通"
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.replace, text)])
        let accepted = try f.accept()
        try f.escrow.seal(accepted, runID: UUID(), expecting: f.handoff.owned().lease)
        let run = try f.execution()
        try f.handoff.send(.cancelStep(accepted.preview.item.id, run.stamp))
        #expect(try f.execution().units.first?.state == .notExecuted)
        try f.returnToDraft()
        let draft = try #require(f.handoff.state().plan.items.first?.draft)
        #expect(draft.arguments == [f.notes(.replace, text)] && f.escrow.count == 0 && todo.notes.isEmpty)
    }

    /// 受保护、required、unknown 仍在准备前被拒（这类草稿本就不能进操作区，这里直接核计划项）；超长正文在准备时被拒。
    @Test func protectedRequirementsStayRejected() throws {
        let f = try TaskSimpleFixture(longText: true)
        let target = CommandDraftTargets(.single, objects: [.init(type: .todo, id: UUID())])
        var drafts = [CommandProtectionRequirement.required, .unknown].map { protection in
            CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.notes"), targets: target,
                         arguments: [f.notes(.replace, "要求")], protectionRequirement: protection)
        }
        var protected = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.notes"),
                                     targets: target, arguments: [f.notes(.clear)])
        protected.acceptProtection(.init(payloadID: UUID(), revision: UUID()))
        drafts.append(protected)
        for draft in drafts {
            let item = CommandPlanItem(id: UUID(), draft: draft)
            #expect(throws: CommandSimpleIssue.invalidArguments) {
                try CommandSimplePreview.validate(item, shape: .fixed(.todo), longText: true)
            }
            #expect(throws: CommandSimpleIssue.invalidArguments) { try f.escrow.preview(item, handles: [:]) { _ in } }
            #expect(draft.blocksUnprotectedExport)
        }
        let todo = try f.insert(TodoItem(title: "超长", dayKey: TaskSimpleFixture.today))
        let long = String(repeating: "长", count: CommandLongTextLimit.maxUTF8Bytes / 3 + 1)
        try f.queue("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.replace, long)])
        #expect(throws: CommandSimpleIssue.invalidArguments) { try f.preview() }
        #expect(f.escrow.count == 0)
    }

    static func preview(_ base: CommandSimplePreview, plan: CommandPlanStamp? = nil, item: CommandPlanItemStamp? = nil,
                        draft: CommandDraftStamp? = nil, input: CommandResolvedInput? = nil) -> CommandSimplePreview {
        .init(lease: base.lease, plan: plan ?? base.plan, item: item ?? base.item, draft: draft ?? base.draft,
              command: base.command, input: input ?? base.input, environmentID: base.environmentID, copy: base.copy,
              before: base.before, after: base.after, creation: base.creation)
    }

    /// 在另一宿主上封存同一指令并占用其第一步。
    static func sealOnTarget(_ f: TaskSimpleFixture, _ todo: TodoItem) throws -> CommandRuntimeInvocation {
        let host = HandoffFixture.target
        try f.handoff.queue(.init(id: UUID(), hostID: host, commandID: .init(rawValue: "todo.notes"),
                                  targets: .init(.single, objects: [.init(type: .todo, id: todo.id)]),
                                  arguments: [f.notes(.replace, "另一宿主")]))
        let lease = try f.handoff.owned(host).lease
        let preview = try f.adapter.prepare(plan: f.handoff.state(host).plan.stamp, expecting: lease)
        let accepted = try f.adapter.accept(preview, expecting: lease)
        try f.escrow.seal(accepted, runID: UUID(), expecting: lease)
        let run = try #require(f.handoff.state(host).execution)
        guard case .attempt(let attempt) = try f.handoff.send(.beginStep(run.stamp), host: host) else {
            throw CommandExecutionError.stale
        }
        let operation = try #require(run.operation(accepted.preview.item.id))
        return try f.handoff.coordinator.claimSimple(.init(lease: f.handoff.owned(host).lease, operation: operation, attempt: attempt))
    }
}
