import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-6 检查点 D：写入侧与系统服务接线。同一份装配、内存容器的 mainContext（自动保存开着，与正式版同形）、
/// 私有事件中心与计数 fake 副作用；不发系统授权、不碰真实剪贴板与窗口。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionCommandTests {
    static let host = UnifiedSearchProductionAssembly.workspaceHost

    static func lease(_ assembly: UnifiedSearchProductionAssembly) throws -> CommandHostLease {
        try assembly.coordinator.host(host).lease
    }

    static func queue(_ assembly: UnifiedSearchProductionAssembly, _ command: String, targets: [CommandObjectReference] = [],
                      single: Bool = true, arguments: [CommandArgument]) throws {
        let coordinator = assembly.coordinator
        let selection: CommandDraftTargets = targets.isEmpty ? .none
            : .init(targets.count == 1 && single ? .single : .selected, objects: targets)
        let draft = CommandDraft(id: UUID(), hostID: host, commandID: .init(rawValue: command), targets: selection, arguments: arguments)
        let state = try coordinator.host(host).session
        try coordinator.send(.operation(.start(expectedRevision: state.operations.revision, draft)), expecting: lease(assembly))
        let next = try coordinator.host(host).session
        try coordinator.send(.enqueue(#require(next.operations.active?.stamp), itemID: UUID(), plan: next.plan.stamp),
                             expecting: lease(assembly))
    }

    static func plan(_ assembly: UnifiedSearchProductionAssembly) throws -> CommandPlanStamp {
        try assembly.coordinator.host(host).session.plan.stamp
    }

    @Test func everyImplementedFamilyIsAssembledAndOriginalPageStaysNavigationOnly() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        #expect(controller.taskCreate != nil && controller.taskTitle != nil && controller.taskField != nil)
        #expect(controller.taskChain != nil && controller.subtask != nil && controller.routine != nil && controller.batch != nil)
        #expect(controller.multiPlan?.supportsRevisions == true && controller.multiPlan?.outputCapability == .typedCreation)
        #expect(controller.trash != nil && controller.taskCopy != nil && controller.convert != nil && controller.clipboard != nil)
        let simple = try #require(controller.simple)
        for command in ["tag.create", "tag.merge", "todo.notes", "routine.capture", "subtask.order", "gantt.shift",
                        "image.trash", "trash.restore", "diary.body", "diary.pinned", "diary.toTodo"] {
            #expect(simple.supports(.init(rawValue: command)), "\(command) 未装配")
        }
        // 永久删除、系统类与附件系统动作仍只打开原页面：骨架不接、页面宿主只导航。
        for command in ["tag.delete", "tag.cleanup", "clipboard.empty", "image.pick", "notification.request"] {
            #expect(CommandOriginalPage.route(for: .init(rawValue: command)) != nil)
            #expect(!simple.supports(.init(rawValue: command)), "\(command) 不应可执行")
            let descriptor = try #require(CommandCatalog.standard.command(id: .init(rawValue: command)))
            #expect(UnifiedSearchController.routesAsNavigation(descriptor), "\(command) 应只走导航")
        }
        #expect(simple.escrow != nil && assembly.escrows.count == 2)
    }

    @Test func createWritesMainContextAndRequestsSystemEffectsOnlyAfterSave() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let adapter = try #require(assembly.workspace.taskCreate)
        try Self.queue(assembly, "todo.create", arguments: TaskCreateCommandFixture.arguments("合成正式版任务", day: UnifiedSearchProductionFixture.today)
            + [.init(parameter: .time, operation: .setReminder, value: .time(510))])
        let preview = try adapter.preview(plan: Self.plan(assembly), expecting: Self.lease(assembly))
        let accepted = try adapter.accept(preview, expecting: Self.lease(assembly))
        // 准备与接受不保存、不授权、不刷新。
        #expect(fixture.saves == 0 && fixture.probe.total == 0)
        let facts = try adapter.submit(accepted: accepted, expecting: Self.lease(assembly))
        #expect(facts.state == .saved)
        let saved = try fixture.context.fetch(FetchDescriptor<TodoItem>())
        #expect(saved.count == 1 && saved.first?.title == "合成正式版任务" && saved.first?.remindMinutes == 510)
        #expect(fixture.saves == 1 && !fixture.context.hasChanges)
        // 授权只在设了提醒且保存成功后请求一次；刷新经原 BoardEvents 路径（含日历）请求一次。
        #expect(fixture.probe.reminderRequests == [510] && fixture.probe.refreshes == [true])
        #expect(facts.authorizationResult == .unknown)
    }

    @Test func settingsKeepLegacyPreferenceAuthority() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let settings = try #require(assembly.workspace.localSettings)
        #expect(fixture.preferences.usesLegacyLocalPreferences && assembly.workspace.fileSettings == nil)
        let coordinator = assembly.coordinator
        let draft = CommandDraft(id: UUID(), hostID: Self.host, commandID: .init(rawValue: "setting.language"),
            arguments: [.init(parameter: .value, operation: .assign, value: .choice("english"))])
        try coordinator.send(.operation(.start(expectedRevision: coordinator.host(Self.host).session.operations.revision, draft)),
                             expecting: Self.lease(assembly))
        try settings.prepare(#require(coordinator.host(Self.host).session.operations.active?.stamp), expecting: Self.lease(assembly))
        let state = try coordinator.host(Self.host).session
        try coordinator.send(.enqueue(#require(state.operations.active?.stamp), itemID: UUID(), plan: state.plan.stamp),
                             expecting: Self.lease(assembly))
        _ = try settings.submit(plan: Self.plan(assembly), expecting: Self.lease(assembly))
        #expect(fixture.preferences.language == .english)
        #expect(fixture.defaults.string(forKey: AppPreferences.languageKey) == AppLanguage.english.rawValue)
        #expect(fixture.preferences.usesLegacyLocalPreferences)
    }

    @Test func protectedDiaryIsStillRefused() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let diary = DiaryEntry(text: "合成受保护手记", dayKey: UnifiedSearchProductionFixture.today)
        diary.isPrivate = true
        try fixture.insert(diary)
        fixture.saves = 0
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let simple = try #require(assembly.workspace.simple)
        try Self.queue(assembly, "diary.pinned", targets: [.init(type: .diary, id: diary.id)],
                       arguments: [.init(parameter: .enabled, operation: .assign, value: .boolean(true))])
        #expect(throws: (any Error).self) {
            try simple.accept(simple.prepare(plan: Self.plan(assembly), expecting: Self.lease(assembly)), expecting: Self.lease(assembly))
        }
        #expect(!diary.isPinned && fixture.saves == 0 && fixture.probe.total == 0)
    }

    @Test func longTextEscrowFollowsLockAndHostClose() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let todo = try fixture.insert(TodoItem(title: "合成备注目标", dayKey: UnifiedSearchProductionFixture.today))
        let assembly = try fixture.assembly()
        let simple = try #require(assembly.workspace.simple)
        let escrow = try #require(simple.escrow)
        try Self.queue(assembly, "todo.notes", targets: [.init(type: .todo, id: todo.id)],
                       arguments: [.init(parameter: .notes, operation: .replace, value: .longText("合成长文正文"))])
        let accepted = try simple.accept(simple.prepare(plan: Self.plan(assembly), expecting: Self.lease(assembly)),
                                         expecting: Self.lease(assembly))
        try escrow.seal(accepted, runID: UUID(), expecting: Self.lease(assembly))
        let handle = try #require(accepted.preview.handles[.notes])
        #expect(escrow.state(handle) == .held && escrow.count == 1)
        // 正式版托管订阅装配事件中心（default）上的保险箱锁定；这里同名事件发在装配的私有中心。
        fixture.center.post(name: .privacyWillLock, object: fixture.vault)
        #expect(escrow.state(handle) == .blocked)
        assembly.discard()
        #expect(escrow.count == 0 && todo.notes.isEmpty && fixture.probe.total == 0)
    }

    @Test func grantAdmitsOnlyItsOwnContext() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let other = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let grant = CommandStoreGrant.production(fixture.context)
        #expect(CommandStoreGrant.admits(fixture.context, center: .default, grant: grant))
        #expect(!CommandStoreGrant.admits(ModelContext(other), center: fixture.center, grant: grant))
        // 没有凭据时保持隔离门槛：default 中心与开着自动保存的 context 都拒绝。
        #expect(!CommandStoreGrant.admits(fixture.context, center: fixture.center, grant: nil))
        let isolated = ModelContext(other)
        isolated.autosaveEnabled = false
        #expect(CommandStoreGrant.admits(isolated, center: fixture.center, grant: nil))
        #expect(!CommandStoreGrant.admits(isolated, center: .default, grant: nil))
    }
}
