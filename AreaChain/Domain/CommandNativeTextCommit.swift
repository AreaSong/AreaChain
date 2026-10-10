import Foundation

extension CommandHandoffCoordinator {
    /// 普通运行内正文与组合位置在同一次原宿主发布中推进；没有仓储/执行能力。
    func acceptNativeText(_ state: CommandDraftEditingState, operation: CommandFieldOperation,
                          expecting stamp: CommandDraftStamp, lease: CommandHostLease, owner: UUID) throws {
        guard nativeTextOwners.contains(owner) else { throw CommandDraftProtectionError.stale }
        try validate(lease)
        var next = try host(lease.ownership.hostID).session
        try next.acceptNativeText(state, operation: operation, expecting: stamp)
        publishPreferenceSession(next, from: lease)
    }
}
