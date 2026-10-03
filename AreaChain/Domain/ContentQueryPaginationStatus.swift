import Foundation

struct ContentQueryPaginationCount: Equatable {
    let displayed: Int
    let known: Int
    var remaining: Int { known - displayed }
}

struct ContentQueryGroupPaginationStatus: Equatable {
    let unit: ContentQueryDisplayUnitID
    let hits: ContentQueryPaginationCount
    let contexts: ContentQueryPaginationCount
    /// 已分配的上下文前缀与展开后实际可见数量分开；折叠不会丢掉前缀进度。
    let loadedContextCount: Int
    var remainingContextToLoad: Int { contexts.known - loadedContextCount }
}

struct ContentQueryPaginationStatus: CustomStringConvertible, CustomDebugStringConvertible {
    let stamp: ContentQueryPaginationStamp
    let visibility: ContentQueryDisplayVisibility
    let units: ContentQueryPaginationCount
    let hits: ContentQueryPaginationCount
    let groups: [ContentQueryGroupPaginationStatus]
    let completeness: ContentQueryBatchCompleteness
    let hasProviderUnprocessedWork: Bool
    let canDeclareCompleteNoMatch: Bool
    var hasMoreUnits: Bool { units.remaining > 0 }
    var hasMoreKnownHits: Bool { hits.remaining > 0 }
    /// 只指仍可加载的已读取内容；收起但已加载的上下文仍由 Browse 的 expand 控制。
    var hasMoreToLoad: Bool {
        hasMoreUnits || hasMoreKnownHits || groups.contains { $0.remainingContextToLoad > 0 }
    }
    var description: String { "ContentQueryPaginationStatus(redacted)" }
    var debugDescription: String { description }
}

extension ContentQueryPaginationState {
    var status: ContentQueryPaginationStatus {
        let source = snapshot.source.source.source
        let groups = snapshot.units.filter { $0.sourceGroup != nil }.map { unit in
            let loaded = snapshot.visibleContext(in: unit).count
            let expanded = unit.sourceGroup.map { browse.expanded.contains(.contextToggle($0)) } ?? false
            return ContentQueryGroupPaginationStatus(unit: unit.id,
                hits: .init(displayed: unit.hits.count - snapshot.knownUndisplayedCount(in: unit.id), known: unit.hits.count),
                contexts: .init(displayed: expanded ? loaded : 0, known: unit.context.count), loadedContextCount: loaded)
        }
        return .init(stamp: stamp, visibility: snapshot.visibility,
            units: .init(displayed: snapshot.visibility.units.count, known: snapshot.units.count),
            hits: .init(displayed: snapshot.visible.count, known: snapshot.known.count), groups: groups,
            completeness: source.completeness, hasProviderUnprocessedWork: source.readings.contains { reading in
                guard case .routineOccurrence(let value) = reading else { return false }
                return !value.coverage.unprocessed.isEmpty || !value.coverage.unprocessedCheckIndices.isEmpty
            }, canDeclareCompleteNoMatch: source.canDeclareCompleteNoMatch)
    }
}
