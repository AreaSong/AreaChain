import SwiftUI

/// 页面只提供展示值和已有动作；导航、筛选与保存仍由原来的状态所有者负责。
struct WorkspaceHeaderAction: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let systemImage: String
    var isEnabled = true
    var isActive = false
    var role: ButtonRole?
    var overflowOnly = false
    var children: [WorkspaceHeaderAction] = []
    var perform: () -> Void = {}
}

struct WorkspaceHeaderContent {
    var actions: [WorkspaceHeaderAction] = []
    var status: AnyView?
}

struct WorkspaceHeaderContentKey: PreferenceKey {
    static let defaultValue = WorkspaceHeaderContent()

    static func reduce(value: inout WorkspaceHeaderContent, nextValue: () -> WorkspaceHeaderContent) {
        let next = nextValue()
        value.actions += next.actions
        if let status = next.status { value.status = status }
    }
}

extension View {
    func workspaceHeader(actions: [WorkspaceHeaderAction] = [], status: AnyView? = nil) -> some View {
        preference(key: WorkspaceHeaderContentKey.self, value: WorkspaceHeaderContent(actions: actions, status: status))
    }

    /// 登记当前页面实际提供的对象，禁止遗留选中项启用其他页面的检查器。
    func workspaceInspectorTargets(_ ids: [UUID]) -> some View {
        modifier(WorkspaceInspectorTargets(ids: Set(ids)))
    }
}

private struct WorkspaceInspectorTargets: ViewModifier {
    @Environment(\.workspaceEmbedded) private var embedded
    let ids: Set<UUID>
    @WorkspaceNavigationContext private var navigation

    func body(content: Content) -> some View {
        let identity = navigation.contentIdentity
        content.onChange(of: Registration(identity: identity, ids: ids), initial: true) { _, current in
            guard embedded, navigation.contentIdentity == current.identity else { return }
            navigation.updateInspectorTargets(current.ids)
        }
    }

    private struct Registration: Equatable {
        var identity: String
        var ids: Set<UUID>
    }
}

extension WorkspaceTab {
    var supportsTaskInspector: Bool {
        switch self {
        case .today, .pending, .allItems, .calendar, .gantt, .quadrant: true
        default: false
        }
    }

    var helpKey: LocalizedStringKey? {
        switch self {
        case .tags: "tags.page.subtitle"
        case .diary: "diary.page.subtitle"
        case .clipboard: "clipboard.subtitle"
        case .attachments: "attachments.hint"
        case .gantt: "gantt.hint"
        case .quadrant: "quadrant.hint"
        default: nil
        }
    }
}
