import Foundation

/// 只评估 liveOnly 的子任务子集；未知能力先阻止，坏记录隔离，不以父匹配结果代替自身条件。
enum SubtaskQueryProvider {
    static func read(_ request: SubtaskQueryRequest) -> SubtaskQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = composition?.types.contains(.subtask) == true && composition?.deletion == .liveOnly
        let uniqueConditions = Set(session.conditions.map(\.id)).count == session.conditions.count
        let valid = session.isStructurallyValid && uniqueConditions
        var response = SubtaskQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.subtask] : [],
                            deletion: composition?.deletion),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics
        )
        guard valid else {
            response.diagnostics = [.init(issue: uniqueConditions ? .invalidQuery : .ambiguousConditionIDs)]
            return response
        }
        guard applicable else { return response }
        if let state = response.typeAnalysis.assessment(for: .subtask)?.readRestriction {
            response.state = state
            return response
        }
        response.diagnostics = requirements(request)
        guard response.diagnostics.isEmpty else { response.state = .blocked; return response }
        evaluate(request, response: &response)
        return response
    }

    private static func requirements(_ request: SubtaskQueryRequest) -> [SubtaskQueryDiagnostic] {
        var result: [SubtaskQueryDiagnostic] = []
        if request.subtaskData == .unavailable { result.append(.init(issue: .missingSubtasks)) }
        if !ContentQuerySnapshotValidation.validDay(request.session.queryDates.todayKey, dates: request.session.queryDates) {
            result.append(.init(issue: .invalidDateContext))
        }
        for condition in request.session.conditions {
            switch condition.value {
            case .clause(let terms):
                for term in terms {
                    if term.atom.dimension == .tag, request.tagNames == nil {
                        result.append(.init(issue: .missingTagNames, conditionIDs: [condition.id]))
                    }
                }
            case .page(.boardDate(let scope, let rule)):
                if rule.evaluation == .agenda && ![.overdue, .upcoming].contains(scope) {
                    result.append(.init(issue: .unsupportedAgendaDate, conditionIDs: [condition.id]))
                }
            case .scope, .page: break
            }
        }
        return result
    }

    private static func evaluate(_ request: SubtaskQueryRequest, response: inout SubtaskQueryResponse) {
        let parents = Dictionary(grouping: request.todos.indices, by: { request.todos[$0].id })
        let children = childPositions(request.todos)
        let matcher = SubtaskQueryMatching(request: request)
        // 身份先在全部输入（含墓碑）中核对，不允许 first-wins 或删除行替同 ID 活对象消歧。
        response.diagnostics += identityDiagnostics(request.todos, parents: parents, children: children)
        for (parentIndex, parent) in request.todos.enumerated() {
            guard parents[parent.id]?.count == 1, parent.deletedAt == nil else { continue }
            let issues = parentIssues(parent, dates: request.session.queryDates)
            guard issues.isEmpty else {
                response.diagnostics += issues.map {
                    .init(issue: $0, object: .init(type: .todo, id: parent.id), inputPositions: [.init(parentIndex: parentIndex)])
                }
                continue
            }
            for (childIndex, child) in parent.subtasks.enumerated() {
                guard children[child.id]?.count == 1, child.todoId == parent.id, child.deletedAt == nil else { continue }
                let position = SubtaskQueryInputPosition(parentIndex: parentIndex, subtaskIndex: childIndex)
                let problems = childDiagnostics(child, request: request, position: position)
                guard problems.isEmpty else { response.diagnostics += problems; continue }
                guard let evidence = matcher.match(child, parent: parent) else { continue }
                response.matches.append(.init(id: .init(type: .subtask, id: child.id), title: child.title,
                                              isDone: child.isDone, createdAt: child.createdAt,
                                              parent: .init(type: .todo, id: parent.id), parentTitle: parent.title,
                                              parentScheduledDay: parent.dayKey, evidence: evidence))
            }
        }
    }

    private static func childPositions(_ todos: [TodoSnapshot]) -> [UUID: [SubtaskQueryInputPosition]] {
        var result: [UUID: [SubtaskQueryInputPosition]] = [:]
        for (parentIndex, parent) in todos.enumerated() {
            for (childIndex, child) in parent.subtasks.enumerated() {
                result[child.id, default: []].append(.init(parentIndex: parentIndex, subtaskIndex: childIndex))
            }
        }
        return result
    }

    private static func identityDiagnostics(
        _ todos: [TodoSnapshot], parents: [UUID: [Int]], children: [UUID: [SubtaskQueryInputPosition]]
    ) -> [SubtaskQueryDiagnostic] {
        var result: [SubtaskQueryDiagnostic] = []
        for (parentIndex, parent) in todos.enumerated() {
            let indices = parents[parent.id] ?? []
            if indices.count > 1, indices.first == parentIndex {
                result.append(.init(issue: .duplicateTodoID, object: .init(type: .todo, id: parent.id),
                                    inputPositions: indices.map { .init(parentIndex: $0) }))
            }
            for (childIndex, child) in parent.subtasks.enumerated() {
                let position = SubtaskQueryInputPosition(parentIndex: parentIndex, subtaskIndex: childIndex)
                let positions = children[child.id] ?? []
                if positions.count > 1, positions.first == position {
                    result.append(.init(issue: .duplicateSubtaskID, object: .init(type: .subtask, id: child.id),
                                        inputPositions: positions))
                }
                if child.todoId != parent.id {
                    result.append(.init(issue: .invalidSubtaskOwner, object: .init(type: .subtask, id: child.id),
                                        inputPositions: [position]))
                }
            }
        }
        return result
    }

    private static func parentIssues(_ parent: TodoSnapshot, dates: ContentQueryDateContext) -> [TodoQueryIssue] {
        var result: [TodoQueryIssue] = []
        if !ContentQuerySnapshotValidation.validDay(parent.dayKey, dates: dates) { result.append(.invalidScheduledDay) }
        if !ContentQuerySnapshotValidation.validTimestamp(parent.createdAt, dates: dates) { result.append(.invalidCreatedAt) }
        return result
    }

    private static func childDiagnostics(
        _ child: SubtaskSnapshot, request: SubtaskQueryRequest, position: SubtaskQueryInputPosition
    ) -> [SubtaskQueryDiagnostic] {
        let object = CommandObjectReference(type: .subtask, id: child.id)
        var result: [SubtaskQueryDiagnostic] = []
        if !ContentQuerySnapshotValidation.validTimestamp(child.createdAt, dates: request.session.queryDates) {
            result.append(.init(issue: .invalidCreatedAt, object: object, inputPositions: [position]))
        }
        let tagConditions = request.session.conditions.filter { condition in
            if case .clause(let terms) = condition.value { return terms.contains { $0.atom.dimension == .tag } }
            return false
        }.map(\.id)
        if !tagConditions.isEmpty, let names = request.tagNames {
            for id in TagIDList.normalized(TagIDList.parse(child.tagIDs)) where names[id] == nil {
                result.append(.init(issue: .missingAssociatedTagName(id), conditionIDs: tagConditions,
                                    object: object, inputPositions: [position]))
            }
        }
        return result
    }
}
