import Foundation
import SwiftData

/// 一个简单修改指令要提供的全部内容。三个方法都只接收冻结后的参数与目标，在骨架给出的 context 里读写。
@MainActor protocol SimpleCommandSpec {
    var command: CommandID { get }
    var shape: CommandSimpleShape { get }
    var copy: CommandSimpleCopy { get }
    /// 只读：目标资格与当前值。目标缺失、重复、已删或受保护时抛 `CommandSimpleIssue.invalidTarget`。
    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState
    /// 只读：按参数推出保存后的值；名称等规则沿用原仓储与原界面，不另定规则。
    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState
    /// 唯一写入：一次原仓储调用。骨架把它包在 ModelChanges 事务里，保存前再读一次核对。
    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws
}

/// 简单指令的显式隔离装配：唯一事务边界与私有发布；只接受内存库、关闭自动保存的干净 context。
@MainActor final class SimpleCommandEnvironment {
    struct Dependencies {
        var transaction: ModelChanges.Boundary
        var validateBeforeTransaction: () throws -> Void = {}
        var registerLocalModification: () throws -> Void = {}
        /// 发布时请求的提醒／日历刷新；隔离环境注入 fake，不碰真实系统服务。
        var refresh: (Bool) -> Void = { _ in }
    }
    let id = UUID()
    let context: ModelContext
    let center: NotificationCenter
    let dependencies: Dependencies

    init(context: ModelContext, center: NotificationCenter, dependencies: Dependencies) throws {
        self.context = context
        self.center = center
        self.dependencies = dependencies
        try validateClean()
    }

    func validateClean() throws {
        guard center !== NotificationCenter.default, !context.autosaveEnabled,
              !context.container.configurations.isEmpty,
              context.container.configurations.allSatisfy(\.isStoredInMemoryOnly) else {
            throw CommandSimpleIssue.unassembled
        }
        guard !context.hasChanges, !ModelChanges.hasActiveTransaction(in: context) else { throw CommandSimpleIssue.stale }
    }

    func publish() throws {
        BoardEvents.changed(dependencies: .init(center: center) { [dependencies] includeCalendar in
            dependencies.refresh(includeCalendar)
        })
    }
}
