import Foundation

/// 随机运行内代次，不等同 requestID、读取预算或展示分页版本；无正文摘要或序列化能力。
struct ContentQueryReadSource: Equatable {
    fileprivate let generation: UUID
}

enum ContentQueryReadMethod: Equatable { case initial, sameSnapshotReevaluation }
enum ContentQueryReadPhase: Equatable { case idle, prepared, computing, awaitingPublication }
enum ContentQueryReadOutcome: Equatable { case published, noProgress, failed, publicationCancelled, sourceInvalidated }

struct ContentQueryReadTask: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let source: ContentQueryReadSource
    let requestID: UUID
    let budget: RoutineOccurrenceQueryBudget
    let method: ContentQueryReadMethod
    fileprivate let identity: UUID
    var description: String { "ContentQueryReadTask(redacted)" }
    var debugDescription: String { description }
}

/// 只能由本文件的完整求值链路签发，外部不能拼装响应；候选不是当前发布结果。
struct ContentQueryReadTicket: CustomStringConvertible, CustomDebugStringConvertible {
    fileprivate let task: ContentQueryReadTask
    fileprivate let snapshot: ContentQueryDisplaySnapshot
    var description: String { "ContentQueryReadTicket(redacted)" }
    var debugDescription: String { description }
}

struct ContentQueryReadPresentation {
    var sortMode: ContentQuerySortMode = .relevance
    var budget = ContentQueryPresentationBudget()
}

struct ContentQueryReadPublication: CustomStringConvertible, CustomDebugStringConvertible {
    let task: ContentQueryReadTask
    fileprivate(set) var pagination: ContentQueryPaginationState
    var response: ContentQueryBatchResponse { pagination.snapshot.source.source.source }
    var description: String { "ContentQueryReadPublication(redacted)" }
    var debugDescription: String { description }
}

struct ContentQueryReadEffect {
    let outcome: ContentQueryReadOutcome
    var pagination: ContentQueryPaginationEffect?
    var activeAnchor: ContentQueryBrowseAnchor?
}

/// 单一运行内所有者。宿主串行调用；不创建线程、仓储、持久缓存、执行闭包或系统权限。
/// 任务仅存身份；冻结 Batch 只在这里保留，求值时临时换预算后调用原同步管线。
final class ContentQueryReadOwner: CustomStringConvertible, CustomDebugStringConvertible {
    private struct FrozenInput {
        let source: ContentQueryReadSource
        let batch: ContentQueryBatch
        let presentation: ContentQueryReadPresentation
    }

    let policy: ContentQueryContinuationPolicy
    let paginationPolicy: ContentQueryPaginationPolicy
    private var frozen: FrozenInput?
    private(set) var request: ContentQueryReadTask?
    private(set) var phase: ContentQueryReadPhase = .idle
    private(set) var outcome: ContentQueryReadOutcome?
    private(set) var published: ContentQueryReadPublication?
    private(set) var attemptedBudget: RoutineOccurrenceQueryBudget?
    /// 最近完整求值的预算反馈可更新，即使无进展时仍保留旧展示；这里只存维度，不复制响应。
    private(set) var continuationRemainder: ContentQueryContinuationRemainder?
    var source: ContentQueryReadSource? { frozen?.source }
    var description: String { "ContentQueryReadOwner(redacted)" }
    var debugDescription: String { description }

    init(policy: ContentQueryContinuationPolicy = .init(), paginationPolicy: ContentQueryPaginationPolicy = .init()) throws {
        guard policy.isValid, paginationPolicy.isValid else { throw ContentQueryReadError.invalidConfiguration }
        self.policy = policy
        self.paginationPolicy = paginationPolicy
    }

    /// 查询、日期环境、数据、保护事实或模式变化只能走此入口；即使 requestID 相同也新建代次。
    @discardableResult
    func begin(_ batch: ContentQueryBatch, presentation: ContentQueryReadPresentation = .init()) throws -> ContentQueryReadTask {
        try policy.validate(batch.options.occurrenceBudget)
        guard presentation.budget.isValid else { throw ContentQueryReadError.invalidConfiguration }
        let source = ContentQueryReadSource(generation: UUID())
        frozen = .init(source: source, batch: batch, presentation: presentation)
        continuationRemainder = nil
        return prepare(source: source, requestID: batch.requestID, budget: batch.options.occurrenceBudget, method: .initial)
    }

    func continueReading(source expected: ContentQueryReadSource, budget: RoutineOccurrenceQueryBudget) throws -> ContentQueryReadTask {
        try validateSource(expected)
        guard request == nil else { throw ContentQueryReadError.busy }
        guard let published, published.task.source == expected, let attemptedBudget else {
            throw ContentQueryReadError.noPublishedResult
        }
        let remainder = continuationRemainder ?? ContentQueryContinuationRemainder(published.response)
        guard !remainder.dimensions.isEmpty else { throw ContentQueryReadError.noBudgetRemainder }
        try policy.validateGrowth(from: attemptedBudget, to: budget, remainder: remainder)
        return prepare(source: expected, requestID: published.task.requestID, budget: budget, method: .sameSnapshotReevaluation)
    }

    /// 同步调用不能即时响应取消；宿主可分开准备、求值与发布，用取消拒绝迟到票据。
    func evaluate(_ task: ContentQueryReadTask) throws -> ContentQueryReadTicket {
        try validateTask(task)
        guard phase == .prepared, let frozen else { throw ContentQueryReadError.invalidPhase }
        phase = .computing
        var input = frozen.batch
        input.options.occurrenceBudget = task.budget
        let response = ContentQueryBatchReader.read(input)
        let sorted = ContentQuerySorter.sort(response, mode: frozen.presentation.sortMode)
        let presentation = ContentQueryPresenter.project(sorted, budget: frozen.presentation.budget, locale: input.options.locale)
        let snapshot = ContentQueryDisplayBuilder.build(presentation)
        try validateTask(task)
        phase = .awaitingPublication
        return .init(task: task, snapshot: snapshot)
    }

    /// 不接受外部 Batch/Response；当前分页修订可能已被加载更多推进，提交使用最新 stamp。
    @discardableResult
    func publish(_ ticket: ContentQueryReadTicket, focused: ContentQueryDisplayControl? = nil) throws -> ContentQueryReadEffect {
        try validateTask(ticket.task)
        guard phase == .awaitingPublication else { throw ContentQueryReadError.invalidPhase }
        let response = ticket.snapshot.source.source.source
        if ticket.task.method == .sameSnapshotReevaluation {
            guard response.occurrenceReading?.state == .evaluated else { return finish(.failed) }
            continuationRemainder = .init(response)
            guard let published, response.advancesOccurrenceWork(over: published.response) else { return finish(.noProgress) }
        }
        var pagination: ContentQueryPaginationState
        var effect: ContentQueryPaginationEffect?
        if let previous = published {
            pagination = previous.pagination
            effect = pagination.reset(to: ticket.snapshot, replacing: pagination.stamp,
                                      focused: focused, preservingActiveVisibility: true)
            guard effect?.didPublish == true else { return finish(.failed) }
        } else {
            pagination = try .init(snapshot: ticket.snapshot, policy: paginationPolicy)
        }
        published = .init(task: ticket.task, pagination: pagination)
        continuationRemainder = .init(response)
        _ = finish(.published)
        return .init(outcome: .published, pagination: effect, activeAnchor: pagination.browse.activeAnchor)
    }

    /// 失败原因是封闭类别，不能回显正文、文件名或底层错误描述。
    @discardableResult
    func fail(_ task: ContentQueryReadTask) throws -> ContentQueryReadEffect {
        try validateTask(task)
        return finish(.failed)
    }

    /// 只取消发布资格，不宣称打断正在运行的正则/枚举；保留最后完整结果与合法浏览状态。
    @discardableResult
    func cancel(_ task: ContentQueryReadTask) throws -> ContentQueryReadEffect {
        try validateTask(task)
        return finish(.publicationCancelled)
    }

    /// 供未来保护代次变化使用的值失效入口。丢弃本所有者的引用，不代表已清理宿主/票据副本或真实敏感缓存。
    func invalidateSource(_ expected: ContentQueryReadSource) throws {
        try validateSource(expected)
        frozen = nil
        published = nil
        attemptedBudget = nil
        continuationRemainder = nil
        _ = finish(.sourceInvalidated)
    }

    /// 加载更多只转交原 Pagination 事件，不触发读取，也不改变来源代次或预算。
    @discardableResult
    func loadMore(_ event: ContentQueryPaginationEvent,
                  focused: ContentQueryDisplayControl? = nil) -> ContentQueryPaginationEffect {
        guard published != nil else { return .init(rejection: .staleSource) }
        return published!.pagination.apply(event, focused: focused)
    }

    @discardableResult
    func applyBrowse(_ event: ContentQueryBrowseEvent) -> ContentQueryBrowseEffect {
        guard published != nil else { return .init(rejection: .staleVersion) }
        return published!.pagination.applyBrowse(event)
    }

    private func prepare(source: ContentQueryReadSource, requestID: UUID, budget: RoutineOccurrenceQueryBudget,
                         method: ContentQueryReadMethod) -> ContentQueryReadTask {
        let task = ContentQueryReadTask(source: source, requestID: requestID, budget: budget, method: method, identity: UUID())
        request = task
        phase = .prepared
        outcome = nil
        attemptedBudget = budget
        return task
    }

    private func validateSource(_ expected: ContentQueryReadSource) throws {
        guard frozen?.source == expected else { throw ContentQueryReadError.staleSource }
    }

    private func validateTask(_ task: ContentQueryReadTask) throws {
        try validateSource(task.source)
        guard request == task else { throw ContentQueryReadError.staleTask }
    }

    private func finish(_ result: ContentQueryReadOutcome) -> ContentQueryReadEffect {
        request = nil
        phase = .idle
        outcome = result
        return .init(outcome: result)
    }
}
