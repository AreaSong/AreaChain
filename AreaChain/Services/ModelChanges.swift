import Foundation
import SwiftData

@MainActor
enum ModelChanges {
    private static var deferredContexts: Set<ObjectIdentifier> = []
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
        save: (ModelContext) throws -> Void = { try $0.save() },
        _ work: () throws -> Void
    ) -> Bool {
        do {
            try transaction(in: context, save: save, work)
            return true
        } catch {
            MutationFeedback.shared.reportFailure(error)
            return false
        }
    }

    /// 组合操作中的仓储 commit 延后到最外层，标题、分类及混合批量只提交一次。
    static func transaction<T>(
        in context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() },
        _ work: () throws -> T
    ) throws -> T {
        let key = ObjectIdentifier(context)
        if deferredContexts.contains(key) { return try work() }
        if context.hasChanges { try context.save() }
        deferredContexts.insert(key)
        defer { deferredContexts.remove(key) }
        do {
            let result = try work()
            try save(context)
            BoardEvents.changed()
            return result
        } catch {
            throw ModelRollback.failure(error, in: context)
        }
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
