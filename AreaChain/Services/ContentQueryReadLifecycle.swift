import Foundation
import Observation
import os

/// 只定义通知来源；失焦对象由隔离宿主显式给出，不查找生产窗口。
struct ContentQueryReadNotifications {
    let privacy: NotificationCenter
    let model: NotificationCenter
    let focus: NotificationCenter
    let focusLost: Notification.Name
    let focusObject: AnyObject
}

enum ContentQueryReadInvalidation: Sendable {
    case willLock, privacyChanged, observation, mask, focusLost, modelChanged
}

enum ContentQueryReadSessionError: Error, Equatable {
    case detached, trackingPending, masked, vaultBusy, vaultUnavailable
    case staleHost, stalePermit, staleTask, noPresentation, noOpenIntent
    case queryMismatch, metadataOnlyRequired, readFailed, cleanupFailed, unexpectedExecutor
    case pageContextRequired
}

/// SDK 的回调类型不携带 actor。锁内只放失效身份，不放查询或业务状态。
/// 非主线程误投递也同步撤权，再排队清理；该安装保持失败关闭，不能靠重读放行。
final class ContentQueryReadGate: Sendable {
    struct State: Sendable {
        var epoch: UInt64 = 0
        var active = true
        var unexpectedExecutor = false
    }
    private let storage = OSAllocatedUnfairLock(initialState: State())
    var state: State { storage.withLock { $0 } }

    @discardableResult
    func revoke(unexpectedExecutor: Bool = false) -> UInt64 {
        storage.withLock {
            $0.epoch &+= 1
            $0.unexpectedExecutor = $0.unexpectedExecutor || unexpectedExecutor
            return $0.epoch
        }
    }

    func detach() {
        storage.withLock { $0.active = false; $0.epoch &+= 1 }
    }

    func deliver(_ event: ContentQueryReadInvalidation,
                 to receive: @escaping @MainActor @Sendable (ContentQueryReadInvalidation) -> Void) {
        guard state.active else { return }
        revoke(unexpectedExecutor: !Thread.isMainThread)
        if Thread.isMainThread {
            // PrivacyVault 的锁定/changed/所有被跟踪 setter 均 @MainActor，
            // NotificationCenter queue:nil 与 Observation onChange 均在变更线程同步调用。
            // macOS 主线程就是 MainActor 执行线程；误投递走下方失败关闭分支，不 main.sync。
            MainActor.assumeIsolated { receive(event) }
        } else {
            Task { @MainActor in receive(event) }
        }
    }
}

/// withObservationTracking 是一次性 will-change 回调，无公开取消句柄。
/// detach 后遗留登记仅弱捕获宿主且 gate.active=false，不再派发或保留业务内容。
final class ContentQueryReadSubscriptions {
    let gate = ContentQueryReadGate()
    private var notifications: [(NotificationCenter, NSObjectProtocol)] = []
    private var observation: ContentQueryReadGate?

    func beginTracking() -> ContentQueryReadGate {
        stopTracking()
        let token = ContentQueryReadGate()
        observation = token
        return token
    }

    func stopTracking() {
        observation?.detach()
        observation = nil
    }

    func observe(_ source: ContentQueryReadNotifications, vault: PrivacyVault,
                 receive: @escaping @MainActor @Sendable (ContentQueryReadInvalidation) -> Void) {
        let identity = ObjectIdentifier(vault)
        for (name, event) in [(Notification.Name.privacyWillLock, ContentQueryReadInvalidation.willLock),
                              (.privacyDidChange, .privacyChanged), (.privacyMask, .mask)] {
            add(source.privacy, name: name, identity: identity, event: event, receive: receive)
        }
        add(source.model, name: .boardDidChange, identity: nil, event: .modelChanged, receive: receive)
        add(source.focus, name: source.focusLost, identity: ObjectIdentifier(source.focusObject),
            event: .focusLost, receive: receive)
    }

    private func add(_ center: NotificationCenter, name: Notification.Name, identity: ObjectIdentifier?,
                     event: ContentQueryReadInvalidation,
                     receive: @escaping @MainActor @Sendable (ContentQueryReadInvalidation) -> Void) {
        let gate = gate
        let token = center.addObserver(forName: name, object: nil, queue: nil) { notification in
            if let identity {
                guard let object = notification.object as AnyObject?, ObjectIdentifier(object) == identity else { return }
            }
            gate.deliver(event, to: receive)
        }
        notifications.append((center, token))
    }

    func detach() {
        gate.detach()
        stopTracking()
        for (center, token) in notifications { center.removeObserver(token) }
        notifications.removeAll()
    }

    deinit { detach() }
}

/// 状态戳不是“全库安全就绪”；只绑定当前 vault 的实际搜索失效维度。
struct ContentQueryVaultStamp: Equatable {
    let identity: ObjectIdentifier
    let generation: UInt64
    let revision: UInt64
    let state: PrivacyVault.State
    let authenticating: Bool
    let changingMethods: Bool

    @MainActor init(_ vault: PrivacyVault) {
        identity = ObjectIdentifier(vault)
        generation = vault.generation
        revision = vault.revision
        state = vault.state
        authenticating = vault.isAuthenticating
        changingMethods = vault.isChangingMethods
    }
}
