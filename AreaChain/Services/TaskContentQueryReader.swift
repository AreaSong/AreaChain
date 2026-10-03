import Foundation
import SwiftData

/// 窄读取依赖只用于注入和故障验证；实体在 MainActor 同步投影，不逃逸到结果或后台任务。
@MainActor
struct TaskContentQueryReads {
    var todos: () throws -> [TodoItem]
    var subtasks: () throws -> [SubtaskItem]
    var tags: (Set<UUID>) throws -> [TagItem]

    init(context: ModelContext) {
        let repository: any TaskRepositoryProtocol = SwiftDataTaskRepository(context: context)
        todos = { try repository.fetchAllTodos(includeDeleted: true) }
        subtasks = { try context.fetch(FetchDescriptor<SubtaskItem>()) }
        tags = { ids in
            let wanted = Array(ids)
            return try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { wanted.contains($0.id) }))
        }
    }
}

enum TaskContentQueryReadIssue: Equatable {
    case todoFetchFailed, subtaskFetchFailed, tagFetchFailed
    case unconvertibleSubtask(id: UUID, index: Int)
    case uncontainedSubtask(id: UUID, index: Int)
    case ambiguousTagID(UUID), missingTagID(UUID), privateTagNameUnavailable(UUID)
}

struct TaskContentQueryReadResult: CustomStringConvertible, CustomDebugStringConvertible {
    let batch: ContentQueryBatch
    let issues: [TaskContentQueryReadIssue]
    /// 仅指本次任务关联 ID 的名字资料，不表示全局标签或私密资料完整。
    let tagNamesCoverage: ContentQuerySourceCoverage
    var description: String { "TaskContentQueryReadResult(redacted)" }
    var debugDescription: String { description }
}

/// 调用方拥有上下文及其未保存变化。读取不提交、不回滚、不发业务事件，也不观察后续变更。
/// 一次无 await 的同步装配冻结值；不承诺多次 fetch 是跨上下文/进程的磁盘事务快照。
@MainActor
struct TaskContentQueryReader {
    private let reads: TaskContentQueryReads

    init(context: ModelContext) { reads = .init(context: context) }
    init(reads: TaskContentQueryReads) { self.reads = reads }

    func readTasks(session: ContentQuerySession, requestID: UUID,
                   options: ContentQueryBatchOptions = .init()) -> TaskContentQueryReadResult {
        var batch = ContentQueryBatch(requestID: requestID, session: session, options: options)
        var issues: [TaskContentQueryReadIssue] = []
        guard readSources(into: &batch, issues: &issues) else { return result(batch) }
        let names = ContentQueryTagNames.read(ContentQueryTagNames.associatedIDs(in: batch), fetch: reads.tags)
        issues += names.issues.map(TaskContentQueryReadIssue.init)
        batch.facts.metadata = .init(tagNames: names.values, privateTagIDs: nil)
        return .init(batch: batch, issues: issues, tagNamesCoverage: names.coverage)
    }

    /// 同批装配复用原任务读取，不先生成一个带独立 metadata 的中间 Batch。
    @discardableResult
    func readSources(into batch: inout ContentQueryBatch, issues: inout [TaskContentQueryReadIssue],
                     imageOwner: Bool = false) -> Bool {
        let session = batch.session
        if case .command = session.input { return false }
        guard session.isStructurallyValid,
              imageOwner || !session.typeAnalysis.possibleTypes.isDisjoint(with: [.todo, .subtask]) else { return false }
        batch.snapshots.todos = readTodos(issues: &issues)
        if !session.typeAnalysis.possibleTypes.isDisjoint(with: [.todo, .subtask]) {
            batch.snapshots.subtasks = readSubtasks(parents: batch.snapshots.todos.values, issues: &issues)
        }
        if batch.snapshots.todos.coverage == .complete { batch.facts.trashCoverage.types[.todo] = .completeIncludingDeleted }
        if batch.snapshots.subtasks.coverage == .complete { batch.facts.trashCoverage.types[.subtask] = .completeIncludingDeleted }
        return true
    }

    private func result(_ batch: ContentQueryBatch) -> TaskContentQueryReadResult {
        .init(batch: batch, issues: [], tagNamesCoverage: .notProvided)
    }

    private func readTodos(issues: inout [TaskContentQueryReadIssue]) -> ContentQueryBatchSource<TodoSnapshot> {
        do {
            return .complete(try reads.todos().map { model in
                var value = model.snapshot
                // 原 snapshot 的活子项视图不是枚举源；Batch 只接收独立 fetch 的平面权威数组。
                value.subtasks = []
                return value
            })
        } catch {
            issues.append(.todoFetchFailed)
            return .failed
        }
    }

    private func readSubtasks(parents: [TodoSnapshot]?, issues: inout [TaskContentQueryReadIssue])
        -> ContentQueryBatchSource<SubtaskSnapshot> {
        do {
            let models = try reads.subtasks()
            let parentIDs = parents.map { Set($0.map(\.id)) }
            var values: [SubtaskSnapshot] = []
            var invalidIDs: Set<UUID> = []
            var incomplete = false
            for (index, model) in models.enumerated() {
                guard let value = model.snapshot else {
                    issues.append(.unconvertibleSubtask(id: model.id, index: index))
                    invalidIDs.insert(model.id)
                    incomplete = true
                    continue
                }
                if let parentIDs, !parentIDs.contains(value.todoId) {
                    issues.append(.uncontainedSubtask(id: value.id, index: index))
                    incomplete = true
                }
                values.append(value)
            }
            // 无父 ID 的行无法进入既有值契约；同 ID 的可转换行也不能成为 first-wins 命中。
            values.removeAll { invalidIDs.contains($0.id) }
            return incomplete ? .partial(values) : .complete(values)
        } catch {
            issues.append(.subtaskFetchFailed)
            return .failed
        }
    }

}
