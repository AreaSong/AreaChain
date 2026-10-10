import SwiftUI

/// 显式宿主依赖只覆盖本棵工作台；未装配的旧入口仍按原共享会话工作。
struct WorkspaceHostContext {
    let navigation: WorkspaceNavigation
    let drafts: EditDrafts
    let filters: BoardFilterSession
    let vault: PrivacyVault
    let clipboard: ClipboardHistorySession
    let shortcuts: ShortcutStore
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
