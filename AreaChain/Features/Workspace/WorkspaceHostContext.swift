import AppKit
import SwiftUI

/// 显式宿主依赖只覆盖本棵工作台；未装配的旧入口仍按原共享会话工作。
struct WorkspaceHostContext {
    let navigation: WorkspaceNavigation
    let drafts: EditDrafts
    let filters: BoardFilterSession
    let vault: PrivacyVault
    let clipboard: ClipboardHistorySession
    let shortcuts: ShortcutStore
    var attachments: AttachmentStore?
}

/// 附件页面读写所用的存储；`ordinaryOnly` 为真时只走普通读取，不解码私密附件。
struct WorkspaceAttachmentStorage {
    let store: AttachmentStore
    let root: URL?
    let ordinaryOnly: Bool

    /// 按宿主决定附件存储的唯一入口：无宿主（生产）沿用共享目录；隔离宿主只用显式注入的存储，
    /// 未注入时为 nil，调用方按"无附件"呈现并禁用写入，绝不回退共享目录（§9.85 N-M2）。
    static func resolve(_ host: WorkspaceHostContext?) -> WorkspaceAttachmentStorage? {
        guard let host else { return .init(store: .shared, root: nil, ordinaryOnly: false) }
        guard let store = host.attachments else { return nil }
        return .init(store: store, root: store.directory(), ordinaryOnly: true)
    }

    /// 缩略图与预览共用的读图入口：生产仍按原共享读取（含私密解码）；隔离宿主只做普通读取。
    static func image(_ reference: AttachmentRef, host: WorkspaceHostContext?) -> NSImage? {
        guard let storage = resolve(host) else { return nil }
        guard storage.ordinaryOnly, let root = storage.root else { return AttachmentStore.image(reference: reference) }
        guard let data = try? storage.store.readOrdinary(reference: reference, root: root) else { return nil }
        return NSImage(data: data)
    }
}

private struct WorkspaceHostContextKey: EnvironmentKey {
    static let defaultValue: WorkspaceHostContext? = nil
}

extension EnvironmentValues {
    var workspaceHostContext: WorkspaceHostContext? {
        get { self[WorkspaceHostContextKey.self] }
        set { self[WorkspaceHostContextKey.self] = newValue }
    }
}

@MainActor @propertyWrapper struct WorkspaceNavigationContext: DynamicProperty {
    @Environment(\.workspaceHostContext) private var host
    var wrappedValue: WorkspaceNavigation { host?.navigation ?? .shared }
    var projectedValue: Bindable<WorkspaceNavigation> { Bindable(wrappedValue: wrappedValue) }
}

@MainActor @propertyWrapper struct WorkspaceBoardContext: DynamicProperty {
    @Environment(\.workspaceHostContext) private var host
    var wrappedValue: BoardSelection { host?.navigation.boardSelection ?? .shared }
    var projectedValue: Bindable<BoardSelection> { Bindable(wrappedValue: wrappedValue) }
}

@MainActor @propertyWrapper struct WorkspaceDraftContext: DynamicProperty {
    @Environment(\.workspaceHostContext) private var host
    var wrappedValue: EditDrafts { host?.drafts ?? .shared }
}

@MainActor @propertyWrapper struct WorkspaceFilterContext: DynamicProperty {
    @Environment(\.workspaceHostContext) private var host
    var wrappedValue: BoardFilterSession { host?.filters ?? .shared }
    var projectedValue: Bindable<BoardFilterSession> { Bindable(wrappedValue: wrappedValue) }
}
