import Foundation

enum ContentQueryPageBinding: Equatable {
    case page(visitID: String)
    case independent(ContentQueryDetachment)
}

enum ContentQueryDetachment: Equatable { case removedPageScope, explicit, userScope, handoff }

struct ContentQueryReturnPoint: Equatable {
    var context: ContentQueryPageContext
    var suppressed: Set<ContentQueryConditionDimension>
}

/// 值类型由各宿主分别持有。没有单例、持久化或操作草稿字段。
struct ContentQuerySession: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let hostID: String
    var page: ContentQueryPageContext
    var input: ContentQueryInput = .content(.init(source: ""))
    var conditions: [ContentQueryCondition] = []
    var binding: ContentQueryPageBinding
    var suppressed: Set<ContentQueryConditionDimension> = []
    var returnPoint: ContentQueryReturnPoint?
    var nextConditionID = 0
    /// 仅用于冻结日期解释和来源；导航始终使用接收宿主的 page/returnPoint。
    var handoffContext: ContentQueryPageContext?

    init(page: ContentQueryPageContext) {
        hostID = page.location.hostID
        self.page = page
        binding = .page(visitID: page.location.visitID)
        refreshAutomaticConditions()
    }

    var showsResults: Bool {
        guard case .content(let query) = input else { return false }
        return !query.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || conditions.contains { $0.origin.isUser }
    }

    var textDiagnostics: [ContentQueryDiagnostic] {
        if case .content(let query) = input { return query.diagnostics }
        return []
    }

    var conditionDiagnostics: [ContentQueryConditionDiagnostic] {
        ContentQueryConditionValidation.diagnostics(conditions, dates: queryDates)
    }

    var queryDates: ContentQueryDateContext { handoffContext?.dates ?? page.dates }
    var description: String { "ContentQuerySession(redacted)" }
    var debugDescription: String { description }

    /// 包括指令输入、显式脱离/抑制和未结束返回上下文；不能用 modification 代替操作意图。
    var requiresHandoffReplacement: Bool {
        if case .command = input { return true }
        if case .content(let query) = input, !query.source.isEmpty { return true }
        return conditions.contains { $0.origin.isUser } || !suppressed.isEmpty
            || returnPoint != nil || binding != .page(visitID: page.location.visitID)
    }

    func handedOff(to target: Self) -> Self {
        var next = Self(page: target.page)
        next.input = input
        next.conditions = conditions.map { condition in
            var moved = condition
            if moved.origin.isPage { moved.origin = .handoffPage(page.location) }
            return moved
        }
        next.nextConditionID = nextConditionID
        // 没有显式 scope 时也要冻结实际 global，不能由接收页补出自己的默认范围。
        if !conditions.contains(where: { $0.value.dimension == .scope }) {
            let frozen = next.makeCondition(.scope(.global), origin: .handoffPage(page.location))
            next.conditions.append(frozen)
        }
        next.binding = .independent(.handoff)
        next.suppressed = suppressed
        next.handoffContext = handoffContext ?? page
        next.returnPoint = .init(context: target.page, suppressed: target.suppressed)
        return next
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
        let explicitDimensions = Set(conditions.filter { $0.origin.isUser }.compactMap { $0.value.dimension })
        conditions.removeAll { $0.origin.isHandoffPage && $0.value.dimension.map(explicitDimensions.contains) == true }
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
