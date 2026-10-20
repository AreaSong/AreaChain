import CryptoKit
import Foundation

/// L-M1b：封存后 longText 参数的替身。只含参数、操作、UTF-8 字节数、带键摘要与托管句柄，不含正文。
/// 只能由协调者的封存核对（`CommandDraft.sealLongText`）放进 Snapshot；编辑入口不接受，计划里出现即拒绝封存。
struct CommandLongTextImprint: Equatable, Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let parameter: CommandParameterID
    let operation: CommandFieldOperation
    let byteCount: Int
    let digest: String
    /// 托管句柄：准备时分配一次，接受与封存沿用同一个，使预览输入与 Run 输入逐字相等。
    let escrow: UUID
    var description: String { "CommandLongTextImprint(\(parameter.rawValue), \(operation.rawValue), \(byteCount)B)" }
    var debugDescription: String { description }
}

/// 每个协调者一把随机生成、只在内存中的 HMAC-SHA256 密钥（L6）。摘要只用于印记与冲突比对，
/// 不跨进程、不落盘；没有密钥就无法用字典猜出短备注。
struct CommandTextDigest: CustomStringConvertible, CustomDebugStringConvertible {
    private let key = SymmetricKey(size: .bits256)
    var description: String { "CommandTextDigest(redacted)" }
    var debugDescription: String { description }

    func hex(_ text: String) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: key).map { String(format: "%02x", $0) }.joined()
    }

    func imprint(_ text: String, parameter: CommandParameterID, operation: CommandFieldOperation,
                 escrow: UUID) -> CommandLongTextImprint {
        .init(parameter: parameter, operation: operation, byteCount: text.utf8.count, digest: hex(text), escrow: escrow)
    }
}

/// 封存时随计划一起交给 Domain 的印记；正文不经此结构。
struct CommandLongTextSealing {
    let imprints: [UUID: [CommandLongTextImprint]]
    let digest: CommandTextDigest
}

extension CommandResolvedInput {
    var longTextImprints: [CommandLongTextImprint] {
        arguments.compactMap { if case .longTextImprint(let imprint)? = $0.value { return imprint }; return nil }
    }
}

extension CommandDraft {
    func declaredType(_ parameter: CommandParameterID) -> CommandParameterType? {
        CommandCatalog.standard.command(id: commandID)?.parameters.first { $0.id == parameter }?.type
    }

    var longTextImprints: [CommandLongTextImprint] {
        arguments.compactMap { if case .longTextImprint(let imprint)? = $0.value { return imprint }; return nil }
    }
}

extension CommandHandoffCoordinator {
    var textDigest: CommandTextDigest { simples.textDigest }

    /// 长文托管的唯一封存入口：与 `.sealPlan` 同一校验与发布，另把正文换成印记；协调者用自己的密钥复核印记。
    func sealLongText(_ plan: CommandPlanStamp, runID: UUID, imprints: [UUID: [CommandLongTextImprint]],
                      expecting lease: CommandHostLease) throws {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        nativeTextOwners.invalidate()
        var next = try host(lease.ownership.hostID).session
        try next.sealPlanForProtocol(plan, runID: runID, longText: .init(imprints: imprints, digest: textDigest))
        publishPreferenceSession(next, from: lease)
    }

    /// 未提交（含取消未开始、锁定阻塞）或核为未写入的单项长文 Run：正文还给草稿，计划项回到可编辑状态。
    func returnLongText(_ execution: CommandExecutionStamp, texts: [UUID: [CommandParameterID: String]],
                        expecting lease: CommandHostLease) throws {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        var next = try host(lease.ownership.hostID).session
        guard let run = next.execution, run.stamp == execution, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first else { throw CommandExecutionError.stale }
        let accepted = simples.acceptances[item.draft.id]
        let verifiedNotApplied = accepted.map { simples.verifiedNotApplied($0.id) } ?? false
        try next.returnLongText(texts: texts, digest: textDigest, verifiedNotApplied: verifiedNotApplied)
        simples.release(item.draft.id)
        publishPreferenceSession(next, from: lease)
    }
}
