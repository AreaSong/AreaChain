import Foundation

/// 仅处理注入的活 todo 快照；图片条件按对象三态求值，不阻断其他确定结果。
enum TodoQueryProvider {
    static func read(_ request: TodoQueryRequest) -> TodoQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = composition?.types.contains(.todo) == true && composition?.deletion == .liveOnly
        let uniqueConditions = Set(session.conditions.map(\.id)).count == session.conditions.count
        let valid = session.isStructurallyValid && uniqueConditions
        var response = TodoQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.todo] : [],
                            deletion: composition?.deletion),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics
        )
        guard valid else {
            response.diagnostics = [.init(issue: uniqueConditions ? .invalidQuery : .ambiguousConditionIDs)]
            return response
        }
        guard applicable else { return response }
        if let state = response.typeAnalysis.assessment(for: .todo)?.readRestriction {
            response.state = state
            return response
        }
        response.diagnostics = requirements(request)
        guard response.diagnostics.isEmpty else { response.state = .blocked; return response }
        evaluate(request, response: &response)
        return response
    }

    private static func requirements(_ request: TodoQueryRequest) -> [TodoQueryDiagnostic] {
        var result: [TodoQueryDiagnostic] = []
        if !validDay(request.session.queryDates.todayKey, dates: request.session.queryDates) {
            result.append(.init(issue: .invalidDateContext))
        }
        for condition in request.session.conditions {
            let issue: TodoQueryIssue?
            switch condition.value {
            case .scope: issue = nil
            case .clause(let terms):
                for term in terms {
                    if let issue = requirement(term.atom, request: request) {
                        result.append(.init(issue: issue, conditionIDs: [condition.id]))
                    }
                }
                issue = nil
            case .page(.tagID(_, matching: .taskOrSubtask)):
                issue = request.subtaskData == .unavailable ? .missingSubtasks : nil
            case .page(.boardDate(let scope, let rule)):
                issue = rule.evaluation == .agenda && ![.overdue, .upcoming].contains(scope) ? .unsupportedAgendaDate : nil
            case .page: issue = nil
            }
            if let issue { result.append(.init(issue: issue, conditionIDs: [condition.id])) }
        }
        guard ContentQueryImageRead.isRequired(request.session.conditions) else { return result }
        // 图片组合需要完整对象求值；可按条件定位的辅助缺口下移，旧请求保持原前置门禁。
        return result.filter { ![.missingTagNames, .missingSubtasks].contains($0.issue) }
    }

    private static func requirement(_ atom: ContentQueryAtom, request: TodoQueryRequest) -> TodoQueryIssue? {
        switch atom {
        case .tag: return request.tagNames == nil ? .missingTagNames : nil
        default: return nil
        }
    }

    private static func evaluate(_ request: TodoQueryRequest, response: inout TodoQueryResponse) {
        let positions = Dictionary(grouping: request.todos.indices, by: { request.todos[$0].id })
        let subtaskCounts = Dictionary(grouping: request.todos.flatMap(\.subtasks), by: \.id).mapValues(\.count)
        let matcher = TodoQueryMatching(request: request)
        for (index, todo) in request.todos.enumerated() {
            let indices = positions[todo.id] ?? []
            guard indices.count == 1 else {
                if indices.first == index {
                    response.diagnostics.append(.init(issue: .duplicateTodoID, object: reference(todo), inputIndices: indices))
                    response.undeterminedObjects.append(reference(todo))
                }
                continue
            }
            guard todo.deletedAt == nil else { continue }
            let problems = recordDiagnostics(todo, request: request, subtaskCounts: subtaskCounts)
            let objectEvaluation = ContentQueryImageRead.isRequired(request.session.conditions)
                && problems.allSatisfy { !$0.conditionIDs.isEmpty }
            guard problems.isEmpty || objectEvaluation else {
                response.diagnostics += problems.map {
                    .init(issue: $0.issue, conditionIDs: $0.conditionIDs, object: reference(todo), inputIndices: [index])
                }
                response.undeterminedObjects.append(reference(todo))
                continue
            }
            let result = matcher.evaluate(todo, diagnostics: problems)
            response.diagnostics += result.diagnostics.map {
                var diagnostic = $0
                diagnostic.object = reference(todo)
                diagnostic.inputIndices = [index]
                return diagnostic
            }
            switch result.truth {
            case .matches:
                response.matches.append(.init(id: reference(todo), title: todo.title, notes: todo.notes,
                                              dayKey: todo.dayKey, createdAt: todo.createdAt, isDone: todo.isDone,
                                              evidence: result.evidence))
            case .unknown: response.undeterminedObjects.append(reference(todo))
            case .doesNotMatch: break
            }
        }
    }

    private static func recordDiagnostics(
        _ todo: TodoSnapshot, request: TodoQueryRequest, subtaskCounts: [UUID: Int]
    ) -> [TodoQueryDiagnostic] {
        var result: [TodoQueryDiagnostic] = []
        let dates = request.session.queryDates
        if !validDay(todo.dayKey, dates: dates) { result.append(.init(issue: .invalidScheduledDay)) }
        if !ContentQuerySnapshotValidation.validTimestamp(todo.createdAt, dates: dates) {
            result.append(.init(issue: .invalidCreatedAt))
        }
        let tagConditions = request.session.conditions.filter { condition in
            if case .clause(let terms) = condition.value { return terms.contains { $0.atom.dimension == .tag } }
            return false
        }.map(\.id)
        if !tagConditions.isEmpty {
            if let names = request.tagNames {
                for id in TagIDList.normalized(TagIDList.parse(todo.tagIDs)) where names[id] == nil {
                    result.append(.init(issue: .missingAssociatedTagName(id), conditionIDs: tagConditions))
                }
            } else {
                result.append(.init(issue: .missingTagNames, conditionIDs: tagConditions))
            }
        }
        result += subtaskDiagnostics(todo, conditions: request.session.conditions, counts: subtaskCounts)
        if request.subtaskData == .unavailable {
            let ids = request.session.conditions.filter {
                if case .page(.tagID(_, matching: .taskOrSubtask)) = $0.value { return true }; return false
            }.map(\.id)
            if !ids.isEmpty { result.append(.init(issue: .missingSubtasks, conditionIDs: ids)) }
        }
        return result
    }

    private static func subtaskDiagnostics(
        _ todo: TodoSnapshot, conditions: [ContentQueryCondition], counts: [UUID: Int]
    ) -> [TodoQueryDiagnostic] {
        let ids = conditions.filter {
            if case .page(.tagID(_, matching: .taskOrSubtask)) = $0.value { return true }
            return false
        }.map(\.id)
        guard !ids.isEmpty else { return [] }
        var result: [TodoQueryDiagnostic] = []
        if todo.subtasks.contains(where: { $0.todoId != todo.id }) {
            result.append(.init(issue: .invalidSubtaskOwner, conditionIDs: ids))
        }
        if todo.subtasks.contains(where: { counts[$0.id] != 1 }) {
            result.append(.init(issue: .duplicateSubtaskID, conditionIDs: ids))
        }
        return result
    }

    private static func validDay(_ key: String, dates: ContentQueryDateContext) -> Bool {
        ContentQuerySnapshotValidation.validDay(key, dates: dates)
    }

    private static func reference(_ todo: TodoSnapshot) -> CommandObjectReference { .init(type: .todo, id: todo.id) }
}
