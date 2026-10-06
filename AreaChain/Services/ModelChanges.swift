import Foundation
import SwiftData

@MainActor
enum ModelChanges {
    /// 显式依赖只在最外层同步事务期间保留。默认闭包惰性访问生产服务。
    @MainActor
    struct Boundary {
        var preSave: @MainActor (ModelContext) throws -> Void = { try $0.save() }
        var save: @MainActor (ModelContext) throws -> Void = { try $0.save() }
        var publish: @MainActor () throws -> Void = { BoardEvents.changed() }
        var reportFailure: @MainActor (Error) -> Void = { MutationFeedback.shared.reportFailure($0) }
    }

    enum CallFact { case notCalled, called, returned }
    enum Phase { case working, saving, rolledBack, recoveryFailed, publishing, finished }
    enum BoundaryError: Error { case finishingTransaction }

    /// 调用事实不是耐久回执；called 而未 returned 不能证明未提交。
    @MainActor
    final class CommitFacts {
        fileprivate(set) var preSave: CallFact = .notCalled
        fileprivate(set) var save: CallFact = .notCalled
        fileprivate(set) var rollback: CallFact = .notCalled
        fileprivate(set) var publication: CallFact = .notCalled
        fileprivate(set) var publicationFailed = false
        fileprivate(set) var phase: Phase = .working
    }

    private static var deferredContexts: Set<ObjectIdentifier> = []
    private static var scopes: [ObjectIdentifier: Scope] = [:]
    private struct Scope {
        let boundary: Boundary
        let facts: CommitFacts
    }
    private struct Effects {
        var committed: [() throws -> Void] = []
        var rolledBack: [() -> Void] = []
        var published: [() -> Void] = []
    }
    private static var effects: [ObjectIdentifier: Effects] = [:]

    static func hasActiveTransaction(in context: ModelContext) -> Bool {
        scopes[ObjectIdentifier(context)] != nil
    }

    /// 嵌套在事务里时延到外层保存成功；直接保存时调用方已经提交，立刻执行。
    static func afterCommit(in context: ModelContext, _ effect: @escaping () -> Void) {
        let key = ObjectIdentifier(context)
        if deferredContexts.contains(key) {
            effects[key, default: Effects()].committed.append(effect)
        } else {
            effect()
        }
    }

    /// 文件只在最外层事务成功后清理；不能把已提交的数据当成仍可 rollback。
    static func afterTransaction(in context: ModelContext, commit: @escaping () throws -> Void,
                                 rollback: @escaping () -> Void) {
        let key = ObjectIdentifier(context)
        precondition(deferredContexts.contains(key))
        effects[key, default: Effects()].committed.append(commit)
        effects[key, default: Effects()].rolledBack.append(rollback)
    }
    /// 只有保存成功才能向角标、通知和日历发布变更；失败后撤销未落盘的模型变化。
    static func commit(_ context: ModelContext) throws {
        guard !deferredContexts.contains(ObjectIdentifier(context)) else { return }
        do {
            try context.save()
        } catch {
            throw ModelRollback.failure(error, in: context)
        }
        BoardEvents.changed()
    }

    static func value<T>(in context: ModelContext? = nil, _ work: () throws -> T) -> T? {
        var started = false
        do {
            if let context, context.hasChanges, !deferredContexts.contains(ObjectIdentifier(context)) {
                try context.save()
            }
            started = true
            return try work()
        } catch {
            let failure = started ? context.map { ModelRollback.failure(error, in: $0) } ?? error : error
            MutationFeedback.shared.reportFailure(failure)
            return nil
        }
    }

    @discardableResult
    static func attempt(in context: ModelContext? = nil, _ work: () throws -> Void) -> Bool {
        value(in: context, work) != nil
    }

    @discardableResult
    static func perform(
        in context: ModelContext,
        save: @MainActor (ModelContext) throws -> Void = { try $0.save() },
        _ work: () throws -> Void
    ) -> Bool {
        do {
            try transaction(in: context, save: save, work)
            return true
        } catch {
            reportFailure(error, in: context, boundary: Boundary())
            return false
        }
    }

    @discardableResult
    static func perform(in context: ModelContext, boundary: Boundary, _ work: () throws -> Void) -> Bool {
        do {
            try transaction(in: context, boundary: boundary, work)
            return true
        } catch {
            reportFailure(error, in: context, boundary: boundary)
            return false
        }
    }

    /// 旧 save 参数仍只替换最终保存；预保存政策保持不变。
    static func transaction<T>(
        in context: ModelContext,
        save: @MainActor (ModelContext) throws -> Void = { try $0.save() },
        _ work: () throws -> T
    ) throws -> T {
        try withoutActuallyEscaping(save) { save in
            try transaction(in: context, boundary: Boundary(save: save)) { try work() }
        }
    }

    /// 同 context 的嵌套调用继承外层边界，内层不能换掉提交或发布者。
    static func transaction<T>(
        in context: ModelContext, boundary: Boundary,
        observe: (CommitFacts) -> Void = { _ in },
        _ work: () throws -> T
    ) throws -> T {
        let key = ObjectIdentifier(context)
        if let scope = scopes[key] {
            observe(scope.facts)
            guard scope.facts.phase == .working else { throw BoundaryError.finishingTransaction }
            return try work()
        }
        let facts = CommitFacts()
        observe(facts)
        // 进入事务前保存已有变化；失败不回滚用户进入前的 pending 内容。
        if context.hasChanges {
            facts.preSave = .called
            try boundary.preSave(context)
            facts.preSave = .returned
        }
        deferredContexts.insert(key)
        scopes[key] = Scope(boundary: boundary, facts: facts)
        defer { deferredContexts.remove(key); effects[key] = nil; scopes[key] = nil }
        let result: T
        do {
            result = try work()
            facts.phase = .saving
            facts.save = .called
            try boundary.save(context)
            facts.save = .returned
        } catch {
            effects[key]?.rolledBack.reversed().forEach { $0() }
            facts.rollback = .called
            do {
                try ModelRollback.restore(context)
                facts.rollback = .returned
                facts.phase = .rolledBack
            } catch let recovery {
                facts.phase = .recoveryFailed
                throw ModelRecoveryError(original: error, recovery: recovery)
            }
            throw error
        }
        publish(in: context, boundary: boundary, facts: facts)
        return result
    }

    private static func publish(in context: ModelContext, boundary: Boundary, facts: CommitFacts) {
        let key = ObjectIdentifier(context)
        facts.phase = .publishing
        for effect in effects[key]?.committed ?? [] {
            do { try effect() }
            catch { boundary.reportFailure(error) }
        }
        facts.publication = .called
        do {
            try boundary.publish()
            facts.publication = .returned
        } catch {
            facts.publicationFailed = true
            boundary.reportFailure(error)
        }
        effects[key]?.published.forEach { $0() }
        facts.phase = .finished
    }

    static func afterPublication(in context: ModelContext, _ effect: @escaping () -> Void) {
        let key = ObjectIdentifier(context)
        if deferredContexts.contains(key) { effects[key, default: Effects()].published.append(effect) }
        else { effect() }
    }

    /// 只用于本次调用的错误反馈；不修改全局生产默认闭包。
    static func reportFailure(_ error: Error, in context: ModelContext, boundary: Boundary) {
        (scopes[ObjectIdentifier(context)]?.boundary ?? boundary).reportFailure(error)
    }

}

enum ModelRollback {
    static func failure(_ original: Error, in context: ModelContext) -> Error {
        do {
            try restore(context)
            return original
        } catch {
            return ModelRecoveryError(original: original, recovery: error)
        }
    }

    static func restore(_ context: ModelContext) throws {
        context.processPendingChanges()
        context.rollback()
        // SwiftData rollback 不会立即更新已持有的 @Model 属性缓存，必须重新物化。
        for model in AreaChainSchema.models {
            try refresh(model, in: context)
        }
    }

    private static func refresh<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) throws {
        _ = try context.fetch(FetchDescriptor<Model>())
    }
}

struct ModelRecoveryError: LocalizedError {
    let original: Error
    let recovery: Error
    var errorDescription: String? { L10n.string("save.rollback.failure", locale: .current) }
}
