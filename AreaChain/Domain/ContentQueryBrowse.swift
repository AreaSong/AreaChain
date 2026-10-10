import Foundation

enum ContentQueryBrowseDirection { case previous, next }
enum ContentQueryBrowseFocus: Equatable {
    case input, hit(CommandObjectReference), control(ContentQueryDisplayControl)
}

/// 仅为宿主导航意图；保留子任务/执行日身份，不授予恢复、删除或编辑资格。
struct ContentQueryBrowseOpen: Equatable {
    let object: CommandObjectReference
    let parent: CommandObjectReference?
    let viewingTrash: Bool
    var requiresFreshBusinessValidation: Bool { true }
}

enum ContentQueryBrowseAction {
    case move(ContentQueryBrowseDirection, inputEditing: Bool)
    case activate(CommandObjectReference)
    case select(CommandObjectReference, Bool)
    case selectVisible, selectAllKnown
    case expand(ContentQueryDisplayControl)
    case collapse(ContentQueryDisplayControl, focused: ContentQueryDisplayControl?)
    case open(inputEditing: Bool)
    case focusInput
    case focusControl(ContentQueryDisplayControl)
}

struct ContentQueryBrowseEvent {
    let version: UUID
    let action: ContentQueryBrowseAction
}

enum ContentQueryBrowseRejection: Equatable { case staleVersion, invalidTarget, editorHasPriority }
struct ContentQueryBrowseEffect: Equatable {
    var rejection: ContentQueryBrowseRejection?
    var focus: ContentQueryBrowseFocus?
    var open: ContentQueryBrowseOpen?
}

/// 浏览集合与 CommandDraftTargets 完全分离。build 或可见性修订生成版本，发布采用比较并替换。
struct ContentQueryBrowseState {
    private(set) var snapshot: ContentQueryDisplaySnapshot
    private(set) var active: CommandObjectReference?
    private(set) var selected: Set<CommandObjectReference> = []
    private(set) var expanded: Set<ContentQueryDisplayControl> = []
    private var published: Set<UUID>

    init(snapshot: ContentQueryDisplaySnapshot) {
        self.snapshot = snapshot
        published = [snapshot.version]
    }

    mutating func publish(_ next: ContentQueryDisplaySnapshot, replacing version: UUID,
                          focused: ContentQueryDisplayControl? = nil) -> ContentQueryBrowseEffect {
        guard version == snapshot.version, !published.contains(next.version) else {
            return .init(rejection: .staleVersion)
        }
        snapshot = next
        published.insert(next.version)
        selected.formIntersection(next.known)
        expanded.formIntersection(Set(toggleControls))
        var effect = ContentQueryBrowseEffect()
        if let active, !next.visible.contains(active) {
            self.active = nil
            effect.focus = .input
        }
        if effect.focus == nil, let focused, !reachableControls.contains(focused) {
            let toggle = toggle(for: focused)
            effect.focus = toggle.map { toggleControls.contains($0) ? .control($0) : .input } ?? .input
        }
        return effect
    }

    mutating func apply(_ event: ContentQueryBrowseEvent) -> ContentQueryBrowseEffect {
        guard event.version == snapshot.version else { return .init(rejection: .staleVersion) }
        switch event.action {
        case .move(let direction, let editing):
            guard !editing else { return .init(rejection: .editorHasPriority) }
            return move(direction)
        case .activate(let id):
            guard snapshot.visible.contains(id) else { return .init(rejection: .invalidTarget) }
            active = id
            return .init(focus: .hit(id))
        case .select(let id, let value):
            guard snapshot.known.contains(id) else { return .init(rejection: .invalidTarget) }
            if value { selected.insert(id) } else { selected.remove(id) }
        case .selectVisible: selected = Set(snapshot.visible)
        case .selectAllKnown: selected = snapshot.known
        case .expand(let control):
            guard toggleControls.contains(control) else { return .init(rejection: .invalidTarget) }
            expanded.insert(control)
        case .collapse(let control, let focused): return collapse(control, focused: focused)
        case .open(let editing):
            guard !editing else { return .init(rejection: .editorHasPriority) }
            return requestOpen()
        case .focusInput: return .init(focus: .input)
        case .focusControl(let control):
            guard reachableControls.contains(control) else { return .init(rejection: .invalidTarget) }
            return .init(focus: .control(control))
        }
        return .init()
    }

    private mutating func move(_ direction: ContentQueryBrowseDirection) -> ContentQueryBrowseEffect {
        let visible = snapshot.visible
        guard !visible.isEmpty else { active = nil; return .init(focus: .input) }
        if let active, let index = visible.firstIndex(of: active) {
            let offset = direction == .next ? 1 : -1
            self.active = visible[min(max(index + offset, 0), visible.count - 1)]
        } else {
            active = direction == .next ? visible.first : visible.last
        }
        return .init(focus: active.map(ContentQueryBrowseFocus.hit))
    }

    private func requestOpen() -> ContentQueryBrowseEffect {
        guard let active, snapshot.visible.contains(active), let row = snapshot.row(active) else {
            return .init(rejection: .invalidTarget)
        }
        let parents = row.relations.filter { $0.role == .parentTask || $0.role == .routine || $0.role == .imageOwner }
        guard parents.count <= 1 else { return .init(rejection: .invalidTarget) }
        let trash = snapshot.source.source.source.matches.contains {
            if case .trash = $0 { return $0.id == active }; return false
        }
        return .init(open: .init(object: active, parent: parents.first?.object, viewingTrash: trash))
    }

    private mutating func collapse(_ control: ContentQueryDisplayControl,
                                   focused: ContentQueryDisplayControl?) -> ContentQueryBrowseEffect {
        guard toggleControls.contains(control) else { return .init(rejection: .invalidTarget) }
        expanded.remove(control)
        if let focused, toggle(for: focused) == control, focused != control {
            return .init(focus: .control(control))
        }
        return .init()
    }
}

extension ContentQueryBrowseState {
    /// Tab 可达身份仅为宿主信息，不模拟系统 Tab 顺序或真实焦点。
    var toggleControls: [ContentQueryDisplayControl] {
        let visible = Set(snapshot.visible)
        return snapshot.units.filter { snapshot.visibility.units.contains($0.id) }.flatMap { unit in
            var controls: [ContentQueryDisplayControl] = []
            if let group = unit.sourceGroup, !unit.context.isEmpty { controls.append(.contextToggle(group)) }
            for hit in unit.hits where visible.contains(hit) {
                controls += (snapshot.row(hit)?.expansion ?? []).map { .bodyToggle($0.object, $0.field) }
            }
            return controls
        }
    }

    var reachableControls: [ContentQueryDisplayControl] {
        toggleControls.flatMap { control -> [ContentQueryDisplayControl] in
            guard expanded.contains(control) else { return [control] }
            switch control {
            case .contextToggle(let id):
                return [control] + snapshot.units.filter { $0.sourceGroup == id }
                    .flatMap { snapshot.visibleContext(in: $0) }.map(ContentQueryDisplayControl.context)
            case .bodyToggle(let id, let field): return [control, .body(id, field)]
            default: return [control]
            }
        }
    }

    func expansionReference(for control: ContentQueryDisplayControl) -> ContentQueryExpansionReference? {
        guard reachableControls.contains(control), case .body(let id, let field) = control else { return nil }
        return snapshot.row(id)?.expansion.first { $0.object == id && $0.field == field }
    }

    fileprivate func toggle(for control: ContentQueryDisplayControl) -> ContentQueryDisplayControl? {
        switch control {
        case .context(let reference): .contextToggle(reference.group)
        case .body(let id, let field): .bodyToggle(id, field)
        case .contextToggle, .bodyToggle: control
        }
    }
}
