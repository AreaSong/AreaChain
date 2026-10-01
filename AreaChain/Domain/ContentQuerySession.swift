import Foundation

enum ContentQueryPageBinding: Equatable {
    case page(visitID: String)
    case independent(ContentQueryDetachment)
}

enum ContentQueryDetachment: Equatable { case removedPageScope, explicit, userScope }

struct ContentQueryReturnPoint: Equatable {
    var context: ContentQueryPageContext
    var suppressed: Set<ContentQueryConditionDimension>
}

/// 值类型由各宿主分别持有。没有单例、持久化或操作草稿字段。
struct ContentQuerySession: Equatable {
    let hostID: String
    var page: ContentQueryPageContext
    var input: ContentQueryInput = .content(.init(source: ""))
    var conditions: [ContentQueryCondition] = []
    var binding: ContentQueryPageBinding
    var suppressed: Set<ContentQueryConditionDimension> = []
    var returnPoint: ContentQueryReturnPoint?
    var nextConditionID = 0

    init(page: ContentQueryPageContext) {
        hostID = page.location.hostID
        self.page = page
        binding = .page(visitID: page.location.visitID)
        refreshAutomaticConditions()
    }

    var showsResults: Bool {
        guard case .content(let query) = input else { return false }
        return !query.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || conditions.contains { !$0.origin.isPage }
    }

    var textDiagnostics: [ContentQueryDiagnostic] {
        if case .content(let query) = input { return query.diagnostics }
        return []
    }

    var conditionDiagnostics: [ContentQueryConditionDiagnostic] {
        ContentQueryConditionValidation.diagnostics(conditions, dates: page.dates)
    }

    var isReady: Bool {
        guard case .content(let query) = input else { return false }
        return query.isReady && conditionDiagnostics.allSatisfy { $0.issue == .duplicateCondition }
    }

    var pageProjection: ContentQueryPageProjection { .make(conditions, context: page) }

    var scope: ContentQueryScopeSelection? {
        let scopes = conditions.compactMap { condition -> ContentQueryScopeSelection? in
            if case .scope(let scope) = condition.value { return scope }
            return nil
        }
        guard scopes.dropFirst().allSatisfy({ $0 == scopes.first }) else { return nil }
        return scopes.first ?? .global
    }

    var composition: ContentQueryComposition? {
        guard let scope else { return nil }
        let includeInactive = conditions.contains { $0.value == .page(.routineStatus(.disabled)) }
        let base = ContentQueryScopeContract.composition(scope, includeInactiveRoutines: includeInactive)
        let types = conditions.reduce(base.types) { types, condition in
            if case .page(.contentTypes(let allowed)) = condition.value { return types.intersection(allowed) }
            return types
        }
        return .init(types: types, routines: base.routines, deletion: base.deletion)
    }

    mutating func makeCondition(_ value: ContentQueryConditionValue, origin: ContentQueryConditionOrigin) -> ContentQueryCondition {
        defer { nextConditionID += 1 }
        return .init(id: .init(rawValue: nextConditionID), value: value, origin: origin)
    }

    mutating func refreshAutomaticConditions() {
        let previous = conditions.filter { $0.origin.isPage }
        conditions.removeAll { $0.origin.isPage }
        guard binding == .page(visitID: page.location.visitID) else { return }
        let userDimensions = Set(conditions.compactMap { $0.value.dimension })
        for value in ContentQueryPageMapping.defaults(page) {
            guard let dimension = value.dimension, !userDimensions.contains(dimension), !suppressed.contains(dimension) else { continue }
            let old = previous.first { $0.value.dimension == dimension && $0.origin == .page(visitID: page.location.visitID) }
            conditions.append(old.map { .init(id: $0.id, value: value, origin: $0.origin) }
                ?? makeCondition(value, origin: .page(visitID: page.location.visitID)))
        }
    }
}

enum ContentQueryEvent {
    case enterPage(ContentQueryPageContext)
    case refreshPage(ContentQueryPageContext)
    case setInput(String)
    case addCondition(ContentQueryConditionValue)
    case editCondition(ContentQueryConditionID, ContentQueryConditionValue)
    case removeCondition(ContentQueryConditionID)
    case pageFilterChanged(ContentQueryPageLocation, ContentQueryConditionDimension, ContentQueryConditionValue?)
    case projectionApplied(ContentQueryPageLocation)
    case detach
    case rebind
    case clearUserQuery
}

/// 仅查询与导航意图；没有执行、操作参数、目标或清空草稿的分支。
enum ContentQueryIntent: Equatable {
    case synchronizePage(ContentQueryPageLocation, ContentQueryPageProjection)
    case returnToPage(ContentQueryPageLocation)
    case requiresQueryEditing([ContentQueryConditionID])
    case rejectedEvent
}

struct ContentQueryTransition: Equatable {
    var state: ContentQuerySession
    var intents: [ContentQueryIntent] = []
}
