import Foundation

enum ContentQueryReducer {
    static func reduce(_ state: ContentQuerySession, _ event: ContentQueryEvent) -> ContentQueryTransition {
        var transition = ContentQueryTransition(state: state)
        apply(event, to: &transition)
        guard !transition.intents.contains(.rejectedEvent) else { return .init(state: state, intents: [.rejectedEvent]) }
        if transition.state.showsResults, transition.state.returnPoint == nil {
            transition.state.returnPoint = .init(context: state.page, suppressed: state.suppressed)
        }
        if shouldReturn(event, next: transition.state) { restoreReturnPoint(&transition) }
        let next = transition.state
        if next.binding == .page(visitID: next.page.location.visitID),
           next.pageProjection != state.pageProjection || next.page.location != state.page.location {
            transition.intents.append(.synchronizePage(next.page.location, next.pageProjection))
        }
        return transition
    }

    private static func apply(_ event: ContentQueryEvent, to transition: inout ContentQueryTransition) {
        let preservesHandoffReturn = transition.state.handoffContext != nil
        switch event {
        case .enterPage(let page): enter(page, into: &transition)
        case .refreshPage(let page): refresh(page, into: &transition)
        case .setInput(let source):
            replaceInput(source, state: &transition.state)
            detachForScopeChange(&transition.state)
        case .addCondition(let value):
            let condition = transition.state.makeCondition(value, origin: .user)
            transition.state.conditions.append(condition)
            detachForScopeChange(&transition.state)
        case .editCondition(let id, let value): edit(id, value: value, transition: &transition)
        case .removeCondition(let id): remove(id, transition: &transition)
        case .pageFilterChanged(let location, let dimension, let value):
            changePageFilter(location, dimension: dimension, value: value, transition: &transition)
        case .projectionApplied: return
        case .detach:
            for index in transition.state.conditions.indices where transition.state.conditions[index].origin.isPage {
                transition.state.conditions[index].origin = .user
            }
            transition.state.binding = .independent(.explicit)
        case .rebind: rebind(&transition)
        case .clearUserQuery:
            transition.state.input = .content(.init(source: ""))
            transition.state.conditions.removeAll { !$0.origin.isPage }
            transition.state.handoffContext = nil
        }
        transition.state.refreshAutomaticConditions()
        if !preservesHandoffReturn, transition.state.returnPoint?.context.location == transition.state.page.location {
            transition.state.returnPoint?.suppressed = transition.state.suppressed
        }
    }

    private static func enter(_ page: ContentQueryPageContext, into transition: inout ContentQueryTransition) {
        guard page.location.hostID == transition.state.hostID else { transition.intents.append(.rejectedEvent); return }
        if page.location.visitID == transition.state.page.location.visitID {
            refresh(page, into: &transition)
            return
        }
        transition.state.page = page
        // 转交后的移除范围仍属独立查询；切页不能把它重新变成页面默认查询。
        if transition.state.handoffContext != nil { return }
        transition.state.suppressed = []
        switch transition.state.binding {
        case .page, .independent(.removedPageScope):
            transition.state.binding = .page(visitID: page.location.visitID)
            detachForScopeChange(&transition.state)
        default: break
        }
    }

    private static func refresh(_ page: ContentQueryPageContext, into transition: inout ContentQueryTransition) {
        guard page.location == transition.state.page.location else { return }
        // 只有自动条件读取新页面快照；已接管维度及原始相对日期输入不因时钟/翻页重新解析。
        transition.state.page = page
    }

    private static func edit(
        _ id: ContentQueryConditionID, value: ContentQueryConditionValue, transition: inout ContentQueryTransition
    ) {
        guard let old = transition.state.conditions.first(where: { $0.id == id }) else {
            transition.intents.append(.rejectedEvent); return
        }
        erase([old], state: &transition.state)
        transition.state.conditions.append(.init(id: old.id, value: value, origin: .user))
        if old.value.dimension != value.dimension, let dimension = old.value.dimension { transition.state.suppressed.insert(dimension) }
        if old.value.dimension == .scope, value.dimension != .scope { transition.state.binding = .independent(.removedPageScope) }
        detachForScopeChange(&transition.state)
    }

    private static func remove(_ id: ContentQueryConditionID, transition: inout ContentQueryTransition) {
        guard let old = transition.state.conditions.first(where: { $0.id == id }) else { return }
        if let dimension = old.value.dimension { transition.state.suppressed.insert(dimension) }
        erase([old], state: &transition.state)
        if old.value.dimension == .scope {
            transition.state.binding = .independent(.removedPageScope)
            if transition.state.conditions.contains(where: { !$0.origin.isPage && $0.value.dimension == .scope }) {
                transition.state.binding = .independent(.userScope)
            }
        }
    }

    private static func changePageFilter(
        _ location: ContentQueryPageLocation, dimension: ContentQueryConditionDimension,
        value: ContentQueryConditionValue?, transition: inout ContentQueryTransition
    ) {
        let state = transition.state
        guard location == state.page.location, state.binding == .page(visitID: location.visitID) else { return }
        let existing = state.conditions.filter { $0.value.dimension == dimension }
        if state.pageProjection.extendedDimensions.contains(dimension), existing.contains(where: { !$0.origin.isPage }) {
            transition.intents.append(.requiresQueryEditing(existing.map(\.id)))
            return
        }
        guard ContentQueryPageProjection.editableDimensions(state.page.page).contains(dimension),
              value == nil || (value?.dimension == dimension && ContentQueryPageProjection.accepts(value!, context: state.page)) else {
            transition.intents.append(.rejectedEvent); return
        }
        if existing.count == 1, existing[0].value == value, !existing[0].origin.isPage { return }
        erase(existing, state: &transition.state)
        if let value {
            let condition = existing.first.map { ContentQueryCondition(id: $0.id, value: value, origin: .user) }
                ?? transition.state.makeCondition(value, origin: .user)
            transition.state.conditions.append(condition)
        } else {
            transition.state.suppressed.insert(dimension)
        }
    }

    private static func rebind(_ transition: inout ContentQueryTransition) {
        let incompatible = incompatibleScopes(transition.state)
        guard incompatible.isEmpty else {
            transition.intents.append(.requiresQueryEditing(incompatible.map(\.id))); return
        }
        transition.state.conditions.removeAll { $0.origin.isHandoffPage }
        transition.state.handoffContext = nil
        transition.state.binding = .page(visitID: transition.state.page.location.visitID)
        transition.state.suppressed.remove(.scope)
    }

    private static func incompatibleScopes(_ state: ContentQuerySession) -> [ContentQueryCondition] {
        let expected = ContentQueryPageMapping.defaults(state.page).first { $0.dimension == .scope } ?? .scope(.global)
        return state.conditions.filter { $0.origin.isUser && $0.value.dimension == .scope && $0.value != expected }
    }

    private static func detachForScopeChange(_ state: inout ContentQuerySession) {
        if !incompatibleScopes(state).isEmpty { state.binding = .independent(.userScope) }
        state.refreshAutomaticConditions()
    }

    private static func replaceInput(_ source: String, state: inout ContentQuerySession) {
        var previous = state.conditions.filter { if case .input = $0.origin { return true }; return false }
        state.conditions.removeAll { if case .input = $0.origin { return true }; return false }
        state.input = ContentQueryParser().parse(source, context: state.queryDates)
        guard case .content(let query) = state.input else { return }
        let values = query.scopes.map { (ContentQueryConditionValue.scope(.catalog($0.scope)), $0.range) }
            + query.clauses.map { (ContentQueryConditionValue.clause($0.alternatives.map(ContentQuerySemanticTerm.init)), $0.range) }
        for (value, range) in values {
            if let index = previous.firstIndex(where: { $0.value == value }) {
                let old = previous.remove(at: index)
                state.conditions.append(.init(id: old.id, value: value, origin: .input(range: range)))
            } else {
                let condition = state.makeCondition(value, origin: .input(range: range))
                state.conditions.append(condition)
            }
        }
    }

    private static func erase(_ conditions: [ContentQueryCondition], state: inout ContentQuerySession) {
        let ids = Set(conditions.map(\.id))
        let ranges = conditions.compactMap { condition -> NSRange? in
            if case .input(let range) = condition.origin { return range }
            return nil
        }.sorted { $0.location > $1.location }
        state.conditions.removeAll { ids.contains($0.id) }
        guard !ranges.isEmpty, case .content(let query) = state.input else { return }
        var source = query.source
        for range in ranges {
            if let nativeRange = Range(range, in: source) { source.removeSubrange(nativeRange) }
        }
        replaceInput(source, state: &state)
    }

    private static func shouldReturn(_ event: ContentQueryEvent, next: ContentQuerySession) -> Bool {
        if case .clearUserQuery = event { return true }
        // 指令候选可暂时隐藏内容结果，但不会撤销此前记录的返回上下文。
        guard next.returnPoint != nil, !next.showsResults, case .content = next.input else { return false }
        switch event {
        case .setInput, .removeCondition, .pageFilterChanged: return true
        default: return false
        }
    }

    private static func restoreReturnPoint(_ transition: inout ContentQueryTransition) {
        guard let point = transition.state.returnPoint else { return }
        transition.state.conditions.removeAll { $0.origin.isHandoffPage }
        transition.state.handoffContext = nil
        transition.state.page = point.context
        transition.state.suppressed = point.suppressed
        transition.state.binding = point.suppressed.contains(.scope)
            ? .independent(.removedPageScope) : .page(visitID: point.context.location.visitID)
        transition.state.returnPoint = nil
        transition.state.refreshAutomaticConditions()
        transition.intents.append(.returnToPage(point.context.location))
    }
}
