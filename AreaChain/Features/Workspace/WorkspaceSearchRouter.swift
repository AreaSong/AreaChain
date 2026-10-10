import AppKit
import SwiftUI

enum WorkspaceNavigationDestination: Equatable {
    case page(WorkspaceTab), day(String), object(WorkspaceObjectLocation)

    var tab: WorkspaceTab {
        if case .page(let tab) = self { return tab }
        return .calendar
    }

    static func page(command: CommandID) -> WorkspaceTab? {
        switch command.rawValue {
        case "go.dashboard": .dashboard
        case "go.today": .today
        case "go.pending": .pending
        case "go.allItems": .allItems
        case "go.calendar": .calendar
        case "go.quadrant": .quadrant
        case "go.gantt": .gantt
        case "go.diaries": .diary
        case "go.images": .attachments
        case "go.clipboard": .clipboard
        case "go.tags": .tags
        case "go.privacy": .privacy
        case "go.backup": .dataBackup
        case "go.trash": .trash
        case "go.settings": .settings
        case "go.shortcuts": .shortcuts
        default: nil
        }
    }
}

enum WorkspaceNavigationOutcome: Equatable {
    case displayed, locatedWithoutInspector, rejected(WorkspaceOpenFailure)
}

/// 仅操作显式装配的现有工作台。实际挂载标记确认呈现；不调用全局窗口/状态项。
@Observable @MainActor final class WorkspaceSearchRouter {
    let navigation: WorkspaceNavigation
    let objects: WorkspaceObjectNavigation
    private(set) var destination: WorkspaceNavigationDestination?
    private(set) var outcome: WorkspaceNavigationOutcome?
    let inspectorFocus = WorkspaceInspectorFocus()
    @ObservationIgnored weak var host: NSView?
    @ObservationIgnored private var mounts: [String: WeakMount] = [:]

    init(navigation: WorkspaceNavigation, objects: WorkspaceObjectNavigation) {
        self.navigation = navigation
        self.objects = objects
    }

    func validateHost() throws {
        guard let window = host?.window, window.isVisible else { throw WorkspaceOpenFailure.unavailable }
        guard window.attachedSheet == nil else { throw WorkspaceOpenFailure.cancelled }
        if let editor = window.firstResponder as? NSTextView, editor.hasMarkedText() {
            throw WorkspaceOpenFailure.composing
        }
    }

    func reveal(_ target: WorkspaceNavigationDestination, valid: () -> Bool) async -> WorkspaceNavigationOutcome {
        do { try validateHost() } catch { return .rejected(error as? WorkspaceOpenFailure ?? .unavailable) }
        guard valid() else { return .rejected(.stale) }
        // 导航卸载与普通失焦不同：原 EditDrafts 保留文字，不能依赖失焦提交。
        inspectorFocus.retainForNavigation()
        navigation.revealSearchDestination(target.tab)
        navigation.navigationObject = nil
        switch target {
        case .page: break
        case .day(let key): navigation.inspectBoard(key)
        case .object(let location):
            navigation.inspectBoard(location.dayKey)
            navigation.navigationObject = location
            navigation.inspectTask(location.inspectorID, dayKey: location.dayKey)
            navigation.inspectedReference = location.object.type == .routineOccurrence
                ? .recurring(location.object.id) : .todo(location.inspectorID)
        }
        destination = target
        outcome = nil
        for _ in 0..<60 {
            guard valid(), destination == target else { return .rejected(.stale) }
            if mounted("page." + target.tab.rawValue) {
                if case .object(let location) = target {
                    if !navigation.isInspectorSpaceAvailable {
                        outcome = .locatedWithoutInspector
                        return .locatedWithoutInspector
                    }
                    let identity = "object." + location.object.id.uuidString
                    if mounted(identity), navigation.isInspectorPresented {
                        outcome = .displayed
                        return .displayed
                    }
                } else {
                    outcome = .displayed
                    return .displayed
                }
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        outcome = .rejected(.unavailable)
        return .rejected(.unavailable)
    }

    func mount(_ view: NSView, key: String) { mounts[key] = WeakMount(view) }
    func unmount(_ view: NSView, key: String) {
        if mounts[key]?.view === view { mounts[key] = nil }
    }
    func mounted(_ key: String) -> Bool {
        guard let view = mounts[key]?.view, view.window === host?.window, view.window != nil,
              !view.isHiddenOrHasHiddenAncestor, !view.visibleRect.isEmpty else { return false }
        return true
    }

    func clearDestination() {
        destination = nil
        navigation.navigationObject = nil
        navigation.closeInspector()
    }

    private final class WeakMount {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }
}

struct WorkspaceNavigationProbe: NSViewRepresentable {
    let router: WorkspaceSearchRouter?
    let key: String

    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.bind(router, key: key) }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.unbind() }

    final class Probe: NSView {
        weak var router: WorkspaceSearchRouter?
        var key = ""
        func bind(_ owner: WorkspaceSearchRouter?, key: String) {
            if router !== owner || self.key != key { unbind() }
            router = owner
            self.key = key
            if window != nil {
                if key == "host" { owner?.host = self }
                owner?.mount(self, key: key)
            }
        }
        func unbind() { router?.unmount(self, key: key) }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { unbind() } else { bind(router, key: key) }
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

private struct WorkspaceSearchRouterKey: EnvironmentKey {
    static let defaultValue: WorkspaceSearchRouter? = nil
}
extension EnvironmentValues {
    var workspaceSearchRouter: WorkspaceSearchRouter? {
        get { self[WorkspaceSearchRouterKey.self] }
        set { self[WorkspaceSearchRouterKey.self] = newValue }
    }
}
