import Foundation

/// 隔离编辑器的窄暂持边界：不接收基线、摘要或任意异步工作；撤权必须同步释放原生正文与撤销。
@MainActor protocol CommandDraftNativeOwner: AnyObject {
    var parameter: CommandParameterID { get }
    func installProtectedContents(_ state: CommandDraftEditingState) throws
    func clearProtectedContents()
}

/// 协调者范围的唯一原生拥有者；不持有正文，外部宿主事件同步撤权。
@MainActor final class CommandNativeTextOwners {
    private var identity: UUID?
    private var revoke: (() -> Void)?

    func attach(_ id: UUID, revoke: @escaping () -> Void) throws {
        guard identity == nil else { throw CommandDraftProtectionError.stale }
        identity = id
        self.revoke = revoke
    }

    func contains(_ id: UUID) -> Bool { identity == id }

    func detach(_ id: UUID) {
        guard identity == id else { return }
        identity = nil
        revoke = nil
    }

    func invalidate() {
        let action = revoke
        identity = nil
        revoke = nil
        action?()
    }
}
