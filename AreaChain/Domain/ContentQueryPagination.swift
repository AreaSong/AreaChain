import Foundation

/// 三个独立展示额度；仅在建立分页时验证，不是提供者读取预算。
struct ContentQueryPaginationPolicy: Equatable {
    var units = 20
    var members = 20
    var contexts = 20
    var isValid: Bool { units > 0 && members > 0 && contexts > 0 }
}

struct ContentQueryPaginationStamp: Equatable {
    let sourceID: UUID
    let revision: UUID
}

enum ContentQueryPaginationAction {
    case loadMoreUnits
    case loadMoreMembers(ContentQueryDisplayUnitID)
    case loadMoreContexts(ContentQueryDisplayUnitID)
}

struct ContentQueryPaginationEvent {
    let stamp: ContentQueryPaginationStamp
    let action: ContentQueryPaginationAction
}

enum ContentQueryPaginationError: Error, Equatable {
    case invalidPageSize, staleSource, staleRevision, invalidTarget, exhausted, sourceAlreadyPublished
}

/// 只记录稳定对象与原组；后续重排可查找身份，不保存下标、像素或正文。
struct ContentQueryBrowseAnchor: Equatable {
    let unit: ContentQueryDisplayUnitID
    let hit: CommandObjectReference
}

struct ContentQueryPaginationEffect: Equatable {
    var rejection: ContentQueryPaginationError?
    var browse = ContentQueryBrowseEffect()
    var previousAnchor: ContentQueryBrowseAnchor?
    var didPublish: Bool { rejection == nil && browse.rejection == nil }
}

/// 唯一浏览状态继续由 BrowseState 管理；本层仅拥有额度、身份进度和原子发布编排。
struct ContentQueryPaginationState: CustomStringConvertible, CustomDebugStringConvertible {
    let policy: ContentQueryPaginationPolicy
    private(set) var browse: ContentQueryBrowseState
    private var progress: ContentQueryPaginationProgress
    private var publishedSources: Set<UUID>
    var snapshot: ContentQueryDisplaySnapshot { browse.snapshot }
    var stamp: ContentQueryPaginationStamp { .init(sourceID: snapshot.sourceID, revision: snapshot.version) }
    var description: String { "ContentQueryPaginationState(redacted)" }
    var debugDescription: String { description }

    init(snapshot: ContentQueryDisplaySnapshot, policy: ContentQueryPaginationPolicy = .init()) throws {
        guard policy.isValid else { throw ContentQueryPaginationError.invalidPageSize }
        self.policy = policy
        var progress = ContentQueryPaginationProgress()
        progress.loadUnits(in: snapshot, policy: policy)
        self.progress = progress
        browse = .init(snapshot: snapshot.revisingVisibility(progress.visibility(in: snapshot)))
        publishedSources = [snapshot.sourceID]
    }

    mutating func applyBrowse(_ event: ContentQueryBrowseEvent) -> ContentQueryBrowseEffect {
        browse.apply(event)
    }

    /// 事件携带产生时的 stamp；成功发布后重放同一事件不会再推进下一段。
    mutating func apply(_ event: ContentQueryPaginationEvent,
                        focused: ContentQueryDisplayControl? = nil) -> ContentQueryPaginationEffect {
        if let rejection = validate(event.stamp) { return .init(rejection: rejection) }
        var nextProgress = progress
        if let rejection = nextProgress.advance(event.action, in: snapshot, policy: policy) {
            return .init(rejection: rejection)
        }
        let next = snapshot.revisingVisibility(nextProgress.visibility(in: snapshot))
        let effect = browse.publish(next, replacing: event.stamp.revision, focused: focused)
        guard effect.rejection == nil else { return .init(browse: effect) }
        progress = nextProgress
        return .init(browse: effect)
    }

    /// 新查询、排序或读取批次须 build 新来源；重建首段并经原 publish 保留合法选择/展开。
    mutating func reset(to source: ContentQueryDisplaySnapshot, replacing stamp: ContentQueryPaginationStamp,
                        focused: ContentQueryDisplayControl? = nil,
                        preservingActiveVisibility: Bool = false) -> ContentQueryPaginationEffect {
        if let rejection = validate(stamp) { return .init(rejection: rejection) }
        guard !publishedSources.contains(source.sourceID) else { return .init(rejection: .sourceAlreadyPublished) }
        let anchor = browse.activeAnchor
        var nextProgress = ContentQueryPaginationProgress()
        nextProgress.loadUnits(in: source, policy: policy)
        if preservingActiveVisibility, let anchor {
            nextProgress.reveal(anchor, in: source, policy: policy)
        }
        let next = source.revisingVisibility(nextProgress.visibility(in: source))
        let effect = browse.publish(next, replacing: stamp.revision, focused: focused)
        guard effect.rejection == nil else { return .init(browse: effect) }
        progress = nextProgress
        publishedSources.insert(source.sourceID)
        return .init(browse: effect, previousAnchor: anchor)
    }

    private func validate(_ expected: ContentQueryPaginationStamp) -> ContentQueryPaginationError? {
        if expected.sourceID != snapshot.sourceID { return .staleSource }
        if expected.revision != snapshot.version { return .staleRevision }
        return nil
    }
}

extension ContentQueryBrowseState {
    var activeAnchor: ContentQueryBrowseAnchor? {
        guard let active, let unit = snapshot.units.first(where: { $0.hits.contains(active) }) else { return nil }
        return .init(unit: unit.id, hit: active)
    }
}

/// 仅保存身份对应的前缀长度；顺序与成员归属永远取自不可变 Display 来源。
private struct ContentQueryPaginationProgress {
    var units = 0
    var members: [ContentQueryDisplayUnitID: Int] = [:]
    var contexts: [ContentQueryDisplayUnitID: Int] = [:]

    /// 重排后只延长到原活动身份所需的前缀；不借用旧页下标，也不改变其他组的成员额度。
    mutating func reveal(_ anchor: ContentQueryBrowseAnchor, in snapshot: ContentQueryDisplaySnapshot,
                         policy: ContentQueryPaginationPolicy) {
        let index = snapshot.units.firstIndex { $0.id == anchor.unit && $0.hits.contains(anchor.hit) }
            ?? snapshot.units.firstIndex { $0.hits.contains(anchor.hit) }
        guard let index, let member = snapshot.units[index].hits.firstIndex(of: anchor.hit) else { return }
        let end = max(units, index + 1)
        for unit in snapshot.units[units..<end] {
            members[unit.id] = min(policy.members, unit.hits.count)
            contexts[unit.id] = min(policy.contexts, unit.context.count)
        }
        units = end
        let id = snapshot.units[index].id
        members[id] = max(members[id, default: 0], member + 1)
    }

    mutating func loadUnits(in snapshot: ContentQueryDisplaySnapshot, policy: ContentQueryPaginationPolicy) {
        let end = advanced(units, by: policy.units, total: snapshot.units.count)
        for unit in snapshot.units[units..<end] {
            members[unit.id] = min(policy.members, unit.hits.count)
            contexts[unit.id] = min(policy.contexts, unit.context.count)
        }
        units = end
    }

    mutating func advance(_ action: ContentQueryPaginationAction, in snapshot: ContentQueryDisplaySnapshot,
                          policy: ContentQueryPaginationPolicy) -> ContentQueryPaginationError? {
        switch action {
        case .loadMoreUnits:
            guard units < snapshot.units.count else { return .exhausted }
            loadUnits(in: snapshot, policy: policy)
        case .loadMoreMembers(let id):
            guard let count = members[id], let unit = snapshot.units.first(where: { $0.id == id }),
                  unit.sourceGroup != nil else { return .invalidTarget }
            guard count < unit.hits.count else { return .exhausted }
            members[id] = advanced(count, by: policy.members, total: unit.hits.count)
        case .loadMoreContexts(let id):
            guard let count = contexts[id], let unit = snapshot.units.first(where: { $0.id == id }),
                  unit.sourceGroup != nil else { return .invalidTarget }
            guard count < unit.context.count else { return .exhausted }
            contexts[id] = advanced(count, by: policy.contexts, total: unit.context.count)
        }
        return nil
    }

    func visibility(in snapshot: ContentQueryDisplaySnapshot) -> ContentQueryDisplayVisibility {
        let shown = snapshot.units.prefix(units)
        return .init(units: Set(shown.map(\.id)),
                     members: Set(shown.flatMap { $0.hits.prefix(members[$0.id, default: 0]) }),
                     contexts: Set(shown.flatMap { $0.context.prefix(contexts[$0.id, default: 0]) }))
    }

    private func advanced(_ count: Int, by size: Int, total: Int) -> Int {
        // count 与 total 均来自安全数组，先取剩余额度再相加，允许 Int.max 额度而不溢出。
        count + min(size, total - count)
    }
}
