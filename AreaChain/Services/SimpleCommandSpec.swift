import Foundation
import SwiftData

/// 一个简单修改指令要提供的全部内容。三个方法都只接收冻结后的参数与目标，在骨架给出的 context 里读写。
@MainActor protocol SimpleCommandSpec {
    var command: CommandID { get }
    var shape: CommandSimpleShape { get }
    var copy: CommandSimpleCopy { get }
    /// 新建型指令声明新对象的类型；骨架在准备时分配一次身份，经 `CommandSimpleCall.creation` 传入。
    var creates: CommandObjectType? { get }
    /// 只读：目标资格与当前值。目标缺失、重复、已删或受保护时抛 `CommandSimpleIssue.invalidTarget`。
    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState
    /// 只读：按参数推出保存后的值；名称等规则沿用原仓储与原界面，不另定规则。
    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState
    /// 唯一写入：一次原仓储调用或一个共享 Services 入口。骨架把它包在 ModelChanges 事务里，保存前再读一次核对。
    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws
    /// 需要新建身份或冻结目标的规格实现这三个；默认转调上面三个。
    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState
    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState
    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws
    /// 保存成功并发布之后的系统后续（如提醒授权请求），返回是否发出了请求；隔离环境由规格注入 fake。
    func afterSave(_ call: CommandSimpleCall, in context: ModelContext) -> Bool
    /// 新建型指令回执里“打开新对象”的位置；沿原导航解析，不另建打开规则。默认没有。
    func openTarget(_ creation: CommandObjectReference) -> ContentQueryBrowseOpen?
    /// 合并批 M-2：为真时只接目录要求独立确认的指令，提交前必须在共用确认面板里确认一次。默认不需要。
    var confirms: Bool { get }
    /// 合并批 M-2：目录要求认证（只为受保护内容）的指令，规格对受保护目标一律拒绝时才可装配；指令里从不认证。
    var refusesProtectedContent: Bool { get }
}

extension SimpleCommandSpec {
    var creates: CommandObjectType? { nil }
    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        try observe(call.input, in: context)
    }
    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        try expect(call.input, from: before, in: context)
    }
    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws { try apply(call.input, in: context) }
    func afterSave(_ call: CommandSimpleCall, in context: ModelContext) -> Bool { false }
    func openTarget(_ creation: CommandObjectReference) -> ContentQueryBrowseOpen? { nil }
    var confirms: Bool { false }
    var refusesProtectedContent: Bool { false }
}

/// 只实现带调用参数版本的规格（新建身份、冻结目标）用这三个默认值满足协议；单独调用会被拒绝。
@MainActor protocol SimpleCommandCallSpec: SimpleCommandSpec {}
extension SimpleCommandCallSpec {
    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        throw CommandSimpleIssue.unassembled
    }
    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState { throw CommandSimpleIssue.unassembled }
    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws { throw CommandSimpleIssue.unassembled }
}

/// L-M1b：参数含 longText 的规格。准备期由托管同步读宿主草稿推出前后状态；执行不经 `apply(call)`，
/// 只经托管为本 attempt 签发的一次性借用写入（借用出口见 CommandLongTextEscrow.swift）。
@MainActor protocol SimpleLongTextCommandSpec: SimpleCommandSpec {
    func apply(_ call: CommandSimpleCall, loan: CommandLongTextLoan, in context: ModelContext) throws
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
