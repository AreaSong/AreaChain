import Foundation
import SwiftData

// 长文受控借用：托管、一次性借用凭据与两个保存出口集中在本文件。
// 只开放普通长文；受保护、required、unknown 在准备前就被拒。正文只在三处出现：宿主草稿、本文件的托管、
// 借用 consume 时交给出口的同步闭包；预览、接受、Snapshot、Run 输入、Facts 与回执只含印记。
// 进程内 String 不承诺零化；同文件代码仍能复制正文，靠单文件审查与 check_workflow 的 long-text-loan 守卫。

enum CommandLongTextLoanError: Error, Equatable {
    /// 没有对应托管：未封存、已销毁、宿主已失效或 Run 已不在。
    case unavailable
    /// plan、item、draft、run、attempt、参数、操作或正文摘要任一不同。
    case mismatch
    /// 同一 attempt 已签过借用；同一 Run 重试只能用新 attempt 新签。
    case alreadyLent
    /// 同一借用第二次 consume，或签发后未 consume。
    case consumed
    /// 锁定、遮罩或隐私变化后签发资格与未用借用全部作废。
    case revoked
    /// 保存结果未知：不再签发，等只读核对。
    case awaitingVerification
}

/// 托管：封存时从宿主草稿移入的普通长文，键为准备时分配的句柄。只在内存，跟随一个协调者与一个隔离环境；
/// 宿主代次或 Run 不在了就销毁，不留孤立明文。
@MainActor final class CommandLongTextEscrow: CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case held, lent(CommandAttemptStamp), blocked, awaitingVerification }
    enum Settlement: Equatable { case saved, notSubmitted, unknown }

    private struct Entry {
        let ownership: CommandHostOwnership
        let plan: CommandPlanStamp
        let item: CommandPlanItemStamp
        let draft: CommandDraftStamp
        let run: CommandExecutionStamp
        let imprint: CommandLongTextImprint
        let text: String
        var state: State
        var lentAttempts: Set<CommandAttemptStamp> = []
    }

    private let coordinator: CommandHandoffCoordinator
    private let center: NotificationCenter
    private var entries: [UUID: Entry] = [:]
    private var epoch: UInt64 = 0
    private var observers: [NSObjectProtocol] = []
    nonisolated var description: String { "CommandLongTextEscrow(redacted)" }
    nonisolated var debugDescription: String { description }

    /// 隐私事件来自注入的事件中心（隔离环境的私有中心）；锁定、隐私变化与遮罩都撤销签发资格。
    init(coordinator: CommandHandoffCoordinator, privacy center: NotificationCenter) {
        self.coordinator = coordinator
        self.center = center
        for name in [Notification.Name.privacyWillLock, .privacyDidChange, .privacyMask] {
            // 与 CommandDraftContentSession 同一投递方式：主队列上同步撤销，不在其他线程假定主线程隔离。
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.revoke() }
            })
        }
    }

    deinit { for observer in observers { center.removeObserver(observer) } }

    /// 仍有效的托管条数；先清掉宿主或 Run 已不在的条目。
    var count: Int {
        prune()
        return entries.count
    }

    func state(_ handle: UUID) -> State? {
        prune()
        return entries[handle]?.state
    }

    /// 预览期：同一个同步调用里直接读宿主草稿的 arguments 得到正文，交给 body 后即弃；返回只含印记的输入。
    /// 句柄沿已分配的（重新校验时），首次准备为每个 longText 参数新分配一个。
    func preview<T>(_ item: CommandPlanItem, handles: [CommandParameterID: UUID],
                    _ body: (CommandResolvedInput) throws -> T) throws -> (CommandResolvedInput, T) {
        let draft = item.draft
        guard !draft.blocksUnprotectedTransfer, draft.protectionRequirement == .ordinary, draft.longTextImprints.isEmpty,
              let command = CommandCatalog.standard.command(id: draft.commandID) else { throw CommandSimpleIssue.invalidArguments }
        let raw = CommandResolvedInput(arguments: draft.arguments + (draft.targets.argument(for: command).map { [$0] } ?? []),
                                       targets: draft.targets)
        guard CommandArgumentValidation.issues(for: raw.arguments, command: command).isEmpty,
              raw.targets.issues(for: command).isEmpty else { throw CommandSimpleIssue.invalidArguments }
        let arguments = raw.arguments.map { argument -> CommandArgument in
            guard draft.declaredType(argument.parameter) == .longText else { return argument }
            let imprint = coordinator.textDigest.imprint(Self.text(argument), parameter: argument.parameter,
                                                         operation: argument.operation,
                                                         escrow: handles[argument.parameter] ?? UUID())
            return .init(parameter: argument.parameter, operation: argument.operation, value: .longTextImprint(imprint))
        }
        let imprinted = CommandResolvedInput(arguments: arguments, targets: raw.targets)
        guard !imprinted.longTextImprints.isEmpty else { throw CommandSimpleIssue.invalidArguments }
        return (imprinted, try body(raw))
    }

    /// 封存期：先核对草稿正文的印记与已接受预览一致（不一致即 stale、要求重新预览），再经协调者封存
    /// （协调者用自己的密钥复核并把 Snapshot 里的正文换成印记）；成功后正文才移入托管。
    func seal(_ accepted: CommandSimpleAcceptance, runID: UUID, expecting lease: CommandHostLease) throws {
        prune()
        let preview = accepted.preview
        let host = try coordinator.host(lease.ownership.hostID)
        guard host.lease == lease, host.session.plan.stamp == preview.plan, host.session.plan.items.count == 1,
              let item = host.session.plan.items.first, item.stamp == preview.item, item.draft.stamp == preview.draft else {
            throw CommandSimpleIssue.stale
        }
        let imprints = preview.input.longTextImprints
        let handles = Dictionary(uniqueKeysWithValues: imprints.map { ($0.parameter, $0.escrow) })
        var texts: [UUID: String] = [:]
        let (input, _) = try self.preview(item, handles: handles) { raw in
            for argument in raw.arguments where item.draft.declaredType(argument.parameter) == .longText {
                if let handle = handles[argument.parameter] { texts[handle] = Self.text(argument) }
            }
        }
        guard input == preview.input, texts.count == imprints.count,
              imprints.allSatisfy({ entries[$0.escrow] == nil }) else { throw CommandSimpleIssue.stale }
        try coordinator.sealLongText(preview.plan, runID: runID, imprints: [item.id: imprints], expecting: lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.snapshot.items.map(\.stamp) == [preview.item] else { throw CommandSimpleIssue.stale }
        for imprint in imprints {
            entries[imprint.escrow] = .init(ownership: lease.ownership, plan: preview.plan, item: preview.item,
                                            draft: preview.draft, run: run.stamp, imprint: imprint,
                                            text: texts[imprint.escrow] ?? "", state: .held)
        }
    }

    /// 执行前的只读检查：锁定后整项转为阻塞（`locked`），其余不可签发都按 stale 处理。
    func checkLendable(_ invocation: CommandRuntimeInvocation, preview: CommandSimplePreview) throws {
        do { _ = try entry(invocation, preview: preview) } catch CommandLongTextLoanError.revoked {
            throw CommandSimpleIssue.invalidTarget(.locked)
        } catch { throw CommandSimpleIssue.stale }
    }

    /// 执行期：每个 attempt 只签一次，绑定 ownership、plan、item、draft、参数、操作、run、attempt 与正文摘要。
    /// 借用只活在 body 这一个同步调用里，body 必须 consume；返回或抛错后借用作废，等调用方按结果 settle。
    func lend<T>(_ invocation: CommandRuntimeInvocation, preview: CommandSimplePreview,
                 _ body: (CommandLongTextLoan) throws -> T) throws -> T {
        var (handle, entry) = try entry(invocation, preview: preview)
        entry.lentAttempts.insert(invocation.attempt)
        entry.state = .lent(invocation.attempt)
        entries[handle] = entry
        let loan = CommandLongTextLoan(escrow: self, handle: handle, imprint: entry.imprint,
                                       attempt: invocation.attempt, epoch: epoch, text: entry.text)
        defer { loan.expire() }
        let value = try body(loan)
        guard loan.consumed else { throw CommandLongTextLoanError.consumed }
        return value
    }

    /// 按执行结果收尾：saved／noChange／核为已写入即销毁；未提交回到可签状态（阻塞的仍阻塞）；未知结果不再签发。
    func settle(_ preview: CommandSimplePreview, _ settlement: Settlement) {
        for imprint in preview.input.longTextImprints {
            guard var entry = entries[imprint.escrow], entry.imprint == imprint else { continue }
            switch settlement {
            case .saved: entries[imprint.escrow] = nil; continue
            case .unknown: entry.state = .awaitingVerification
            case .notSubmitted: if case .lent = entry.state { entry.state = .held }
            }
            entries[imprint.escrow] = entry
        }
    }

    /// 失败、取消未开始、锁定阻塞或核为未写入：正文按印记核对后还回宿主草稿，托管随即销毁。
    func returnToDraft(_ execution: CommandExecutionStamp, expecting lease: CommandHostLease) throws {
        prune()
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution, run.stamp == execution,
              run.snapshot.items.count == 1, let item = run.snapshot.items.first else { throw CommandLongTextLoanError.unavailable }
        let imprints = item.draft.longTextImprints
        var texts: [CommandParameterID: String] = [:]
        for imprint in imprints {
            guard let entry = entries[imprint.escrow], entry.imprint == imprint, entry.run == execution,
                  entry.ownership == lease.ownership else { throw CommandLongTextLoanError.unavailable }
            if case .lent = entry.state { throw CommandLongTextLoanError.alreadyLent }
            texts[imprint.parameter] = entry.text
        }
        guard !texts.isEmpty else { throw CommandLongTextLoanError.unavailable }
        try coordinator.returnLongText(execution, texts: [item.id: texts], expecting: lease)
        for imprint in imprints { entries[imprint.escrow] = nil }
    }

    /// 宿主被放弃或强制失效：该宿主的托管随之销毁。
    func discard(_ ownership: CommandHostOwnership) {
        entries = entries.filter { $0.value.ownership.hostID != ownership.hostID }
    }

    /// 锁定、遮罩或隐私变化：推进代次，未用借用与签发资格全部作废，该项转为阻塞（须返回编辑后重新预览再封存）。
    func revoke() {
        epoch &+= 1
        prune()
        for (handle, entry) in entries where entry.state != .awaitingVerification {
            var next = entry
            next.state = .blocked
            entries[handle] = next
        }
    }

    fileprivate func honors(_ loan: CommandLongTextLoan, text: String) -> Bool {
        guard loan.epoch == epoch, let entry = entries[loan.handle], entry.imprint == loan.imprint,
              entry.state == .lent(loan.attempt), entry.text == text else { return false }
        return coordinator.textDigest.imprint(text, parameter: loan.imprint.parameter, operation: loan.imprint.operation,
                                              escrow: loan.handle) == loan.imprint
    }

    private func entry(_ invocation: CommandRuntimeInvocation,
                       preview: CommandSimplePreview) throws -> (UUID, Entry) {
        prune()
        try coordinator.validateRuntimeInvocation(invocation)
        let attempt = invocation.attempt
        let imprints = preview.input.longTextImprints
        guard imprints.count == 1, let imprint = imprints.first, let entry = entries[imprint.escrow] else {
            throw CommandLongTextLoanError.unavailable
        }
        guard entry.ownership == invocation.lease.ownership, entry.run == attempt.execution,
              entry.run == invocation.operation.execution, attempt.phase == .local, entry.plan == preview.plan,
              entry.item == preview.item, entry.item.id == invocation.operation.operationID, entry.item.id == attempt.unitID,
              entry.draft == preview.draft, entry.imprint == imprint else { throw CommandLongTextLoanError.mismatch }
        switch entry.state {
        case .held: break
        case .blocked: throw CommandLongTextLoanError.revoked
        case .awaitingVerification: throw CommandLongTextLoanError.awaitingVerification
        case .lent: throw CommandLongTextLoanError.alreadyLent
        }
        guard !entry.lentAttempts.contains(attempt) else { throw CommandLongTextLoanError.alreadyLent }
        return (imprint.escrow, entry)
    }

    /// 托管只跟随仍有效的宿主代次与仍在的 Run；任何一个不在了就销毁。
    private func prune() {
        entries = entries.filter { _, entry in
            guard let host = try? coordinator.host(entry.ownership.hostID), host.lease.ownership == entry.ownership else {
                return false
            }
            return host.session.execution?.stamp == entry.run
        }
    }

    private static func text(_ argument: CommandArgument) -> String {
        if case .longText(let text)? = argument.value { return text }
        return ""
    }
}

/// 一次性借用凭据（仿 CommandDraftCheckpoint）：构造器与正文取值器都是 fileprivate，模块内其他文件拿不到正文；
/// 只能 consume 一次；不 Equatable、不可编码；描述固定脱敏；只活在签发它的同步调用里，不进任何异步任务。
/// MainActor 类隐式 Sendable，因此不以“非 Sendable”作为不可外传的保证。
@MainActor final class CommandLongTextLoan: CustomStringConvertible, CustomDebugStringConvertible {
    let parameter: CommandParameterID
    let operation: CommandFieldOperation
    fileprivate let handle: UUID
    fileprivate let imprint: CommandLongTextImprint
    fileprivate let attempt: CommandAttemptStamp
    fileprivate let epoch: UInt64
    private unowned let escrow: CommandLongTextEscrow
    fileprivate var lentText: String?
    private(set) var consumed = false
    nonisolated var description: String { "CommandLongTextLoan(redacted)" }
    nonisolated var debugDescription: String { description }

    fileprivate init(escrow: CommandLongTextEscrow, handle: UUID, imprint: CommandLongTextImprint,
                     attempt: CommandAttemptStamp, epoch: UInt64, text: String) {
        self.escrow = escrow
        self.handle = handle
        self.imprint = imprint
        self.attempt = attempt
        self.epoch = epoch
        parameter = imprint.parameter
        operation = imprint.operation
        lentText = text
    }

    fileprivate func expire() { lentText = nil }

    /// 只交给同步、不逃逸的 body；二次 consume、锁定后、托管已不在、参数或摘要不符都拒绝且不交出正文。
    fileprivate func consumeText<T>(_ expected: CommandParameterID,
                                    _ body: (String, CommandFieldOperation) throws -> T) throws -> T {
        guard !consumed else { throw CommandLongTextLoanError.consumed }
        consumed = true
        guard let text = lentText else { throw CommandLongTextLoanError.revoked }
        lentText = nil
        guard expected == parameter, escrow.honors(self, text: text) else { throw CommandLongTextLoanError.revoked }
        return try body(text, operation)
    }
}

extension TaskNotesService {
    /// 备注的借用出口：一次 consume 内把同一份正文按 replace／append／clear 依次写入全部目标，仍走 `apply(String…)`，
    /// 因此 #标签、提醒、优先级与 @附件 与详情页同一规则；事务由调用方提供。
    static func applyLent(_ loan: CommandLongTextLoan, to todos: [TodoItem], repository: any TaskRepositoryProtocol,
                          in context: ModelContext, attachments: Attachments) throws {
        try loan.consumeText(.notes) { text, operation in
            let edit = try NotesEdit(operation, text: text)
            for todo in todos {
                try apply(edit.final(todo.notes), to: todo, repository: repository, in: context, attachments: attachments)
            }
        }
    }

    static func applyLent(_ loan: CommandLongTextLoan, to routines: [DailyRoutine], repository: any RoutineRepositoryProtocol,
                          in context: ModelContext, attachments: Attachments) throws {
        try loan.consumeText(.notes) { text, operation in
            let edit = try NotesEdit(operation, text: text)
            for routine in routines {
                try apply(edit.final(routine.notes), to: routine, repository: repository, in: context, attachments: attachments)
            }
        }
    }
}

extension RoutineCaptureService {
    /// 快速新增的借用出口：正文只交给原 `apply(Request…)`；新习惯身份、排序与日期由调用方在准备与写入时给出。
    @discardableResult
    static func applyLent(_ loan: CommandLongTextLoan, sortOrder: Int, creationID: UUID, createdDayKey: String,
                          repository: any RoutineRepositoryProtocol, in context: ModelContext,
                          attachments: TaskNotesService.Attachments) throws -> DailyRoutine {
        try loan.consumeText(.body) { text, operation in
            guard operation == .assign else { throw CommandSimpleIssue.invalidArguments }
            return try apply(.init(text: text, sortOrder: sortOrder, creationID: creationID, createdDayKey: createdDayKey),
                             repository: repository, in: context, attachments: attachments).0
        }
    }
}

extension DiaryWriteService {
    /// 新建手记的身份与位置：身份在准备时分配一次（重试不另建），日期与额外标签来自冻结参数。
    struct LentCreation {
        let id: UUID
        let dayKey: String
        let tagIDs: Set<UUID>
    }

    /// 新建普通手记的借用出口。正文按手记页快速新增的“自动分类”拆出正文与标签，再交原 `add`
    /// （不允许锁定时插入）；要关联私密标签或保存后会变成受保护时，在写入前拒绝。事务由调用方提供。
    @discardableResult
    static func applyLent(_ loan: CommandLongTextLoan, creating creation: LentCreation,
                          repository: SwiftDataDiaryRepository, in context: ModelContext) throws -> DiaryEntry {
        try loan.consumeText(.body) { text, operation in
            guard operation == .assign else { throw CommandSimpleIssue.invalidArguments }
            let captured = capture(text.trimmingCharacters(in: .whitespacesAndNewlines))
            guard !captured.text.isEmpty else { throw CommandSimpleIssue.invalidTarget(.diaryEmpty) }
            guard CommandLongTextLimit.allows(captured.text) else { throw CommandSimpleIssue.invalidTarget(.diaryTooLong) }
            let tags = try context.fetch(FetchDescriptor<TagItem>())
            guard !containsPrivateTag(creation.tagIDs, tags: tags),
                  !capturesPrivateTag(captured, tags: tags) else { throw CommandSimpleIssue.invalidTarget(.diaryPrivateTag) }
            let ids = creation.tagIDs.union(try InputTagResolver.resolve(captured.tagNames, in: context))
            guard !becomesProtected(text: captured.text, tagIDs: ids, tags: tags) else {
                throw CommandSimpleIssue.invalidTarget(.protectedDiary)
            }
            return try repository.addDiary(text: captured.text, dayKey: creation.dayKey, tagIDs: ids,
                                           allowLockedInsert: false, creationID: creation.id)
        }
    }

    /// 普通手记正文改写（replace／append）的借用出口，交原 `editDiary`（#标签合并、@附件关联同原界面）。
    /// 目标受保护时在取出正文前就拒绝（不读、不解密）；改写后会变成受保护时在写入前拒绝。
    static func applyLent(_ loan: CommandLongTextLoan, editing entry: DiaryEntry,
                          repository: SwiftDataDiaryRepository, in context: ModelContext) throws {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        guard isOrdinary(entry, tags: tags) else { throw CommandSimpleIssue.invalidTarget(.protectedDiary) }
        try loan.consumeText(.body) { text, operation in
            let final = try BodyEdit(operation, text: text).final(entry.text)
            guard CommandLongTextLimit.allows(final) else { throw CommandSimpleIssue.invalidTarget(.diaryTooLong) }
            guard !becomesProtected(text: final, tagIDs: Set(TagIDList.parse(entry.tagIDs)), tags: tags) else {
                throw CommandSimpleIssue.invalidTarget(.diaryPrivateTag)
            }
            try repository.editDiary(id: entry.id, text: final)
        }
    }
}
