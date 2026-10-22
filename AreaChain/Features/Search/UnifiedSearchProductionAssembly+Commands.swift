import AppKit
import SwiftData

/// 唯一装配点的指令部分：各适配器与规格接真实依赖。所有写入只经原仓储与 ModelChanges，保存成功才发布；
/// 设置类沿用当前正式版的偏好权威（AppPreferences 旧键 + LocalSettingCommandAdapter），不切文件后端、不迁移。
/// 能力按前面各批已实现并复核的范围打开；系统类、永久删除类仍只在 CommandOriginalPage 里打开原页面，这里不装配执行。
extension UnifiedSearchProductionAssembly {
    struct Commands {
        let settings: LocalSettingCommandAdapter
        var taskCreate: TaskCreateCommandAdapter?
        var taskTitle: TaskTitleCommandAdapter?
        var taskField: TaskFieldCommandAdapter?
        var taskChain: TaskChainCommandAdapter?
        var subtask: SubtaskCommandAdapter?
        var routine: RoutineCommandAdapter?
        var batch: BatchCommandAdapter?
        var multiPlan: MultiPlanCommandAdapter?
        var trash: TrashCommandAdapter?
        var taskCopy: TaskCopyCommandAdapter?
        var convert: ConvertCommandAdapter?
        var simple: SimpleCommandAdapter?
        var clipboard: ClipboardCaptureCommandAdapter?
    }

    /// 来源所有者：统一搜索输入框不是安全输入，目标与输入都按普通内容声明；修订在隐私事件后更新，
    /// 使锁定前接受的预览全部作废。字段级变化由各适配器的冻结目标与逐字段复核拦截。
    var ordinarySource: CommandTaskTitleEligibility { .init(revision: sourceRevision, protection: .ordinary) }
    var ordinaryProof: CommandSubtaskEligibility.Proof { .init(revision: sourceRevision, protection: .ordinary) }

    func makeCommands() throws -> Commands {
        let settings = LocalSettingCommandAdapter(coordinator: coordinator, preferences: services.preferences)
        let create = TaskCreateCommandAdapter(coordinator: coordinator, environment: try taskCreateEnvironment(),
                                              capability: .ordinaryComposition)
        let title = TaskTitleCommandAdapter(coordinator: coordinator, environment: try titleEnvironment())
        let field = TaskFieldCommandAdapter(coordinator: coordinator, environment: try titleEnvironment(), capability: .milestone2)
        let subtask = SubtaskCommandAdapter(coordinator: coordinator, environment: try subtaskEnvironment())
        let routine = RoutineCommandAdapter(coordinator: coordinator, environment: try routineEnvironment())
        let batch = BatchCommandAdapter(coordinator: coordinator, environment: try batchEnvironment())
        let multi = MultiPlanCommandAdapter(coordinator: coordinator, adapters: .init(taskCreate: create, taskTitle: title,
            taskField: field, subtask: subtask, routine: routine, batch: batch, localSettings: settings),
            outputCapability: .typedCreation, supportsRevisions: true)
        return Commands(settings: settings, taskCreate: create, taskTitle: title, taskField: field,
            taskChain: TaskChainCommandAdapter(create: create, title: title), subtask: subtask, routine: routine,
            batch: batch, multiPlan: multi,
            trash: TrashCommandAdapter(coordinator: coordinator, environment: try batchEnvironment(), capability: .softTrash),
            taskCopy: TaskCopyCommandAdapter(coordinator: coordinator, environment: try TaskCopyCommandEnvironment(
                context: context, source: { [unowned self] _ in ordinarySource }, writer: services.effects.clipboardWriter,
                grant: grant)),
            convert: ConvertCommandAdapter(coordinator: coordinator, environment: try batchEnvironment(), capability: .convert,
                clock: .init(now: services.now, today: services.today, calendar: services.calendar),
                refreshCalendar: services.effects.refreshCalendar),
            simple: SimpleCommandAdapter(coordinator: coordinator, environment: try SimpleCommandEnvironment(
                context: context, center: services.center,
                dependencies: .init(transaction: .init(), refresh: services.effects.refresh), grant: grant),
                specs: simpleSpecs(), capability: .open),
            clipboard: ClipboardCaptureCommandAdapter(coordinator: coordinator, environment: try clipboardEnvironment()))
    }

    func makePageCommands() -> WorkspacePageCommands {
        let pages = WorkspacePageCommands(router: router, host: hostContext, context: context)
        pages.today = services.today
        pages.calendar = services.calendar
        pages.clipboard = services.effects.clipboardActions()
        pages.system = services.effects.system()
        return pages
    }

    // MARK: - 环境（凭据只放行主 context；干净与事务检查照旧）

    private var context: ModelContext { services.context }
    private var grant: CommandStoreGrant { CommandStoreGrant.production(services.context) }
    /// 正式版写入落共享附件目录（root nil，与原界面相同）；测试落注入的临时目录。
    private var writeRoot: URL? { services.productionAttachments ? nil : services.attachmentRoot }
    private func tasks(_ context: ModelContext) -> any TaskRepositoryProtocol {
        SwiftDataTaskRepository(context: context, attachmentStore: services.attachments)
    }
    private func routines(_ context: ModelContext) -> any RoutineRepositoryProtocol {
        SwiftDataRoutineRepository(context: context, attachmentStore: services.attachments)
    }
    private func diaries(_ context: ModelContext) -> SwiftDataDiaryRepository {
        SwiftDataDiaryRepository(context: context, vault: services.vault, attachmentStore: services.attachments,
                                 attachmentRoot: writeRoot)
    }
    /// 保存成功后才由 BoardEvents 调用：与原界面同一刷新路径；异步处理，结果如实记为 unknown。
    private func refresh(_ includeCalendar: Bool) -> TaskTitleCommandEnvironment.Refresh {
        services.effects.refresh(includeCalendar)
        return .init(notificationRequested: true, calendarRequested: includeCalendar && services.effects.calendarSyncEnabled())
    }
    private func authorize(_ minutes: Int) -> CommandTaskTitleFacts.Authorization {
        services.effects.requestReminderAccess(minutes)
        return .unknown
    }

    private func taskCreateEnvironment() throws -> TaskCreateCommandEnvironment {
        let effects = services.effects
        let dependencies = TaskMutationService.Dependencies(sourceBundleID: effects.sourceBundleID,
            repository: { [unowned self] in tasks($0) }, transaction: .init(), registerLocalCreation: { _ in },
            requestReminderAccessIfNeeded: effects.requestReminderAccess)
        return try .init(context: context, center: services.center, source: { [unowned self] in
            // 偏好关时来源必须为空（与原界面 CaptureStamp.current 同一规则），不交给注入方猜。
            let stamps = services.preferences.stampCaptureApp
            return .init(protection: .ordinary, stampEnabled: stamps, bundleID: stamps ? effects.sourceBundleID() : "")
        }, dependencies: dependencies, refresh: { [unowned self] includeCalendar in
            let observed = refresh(includeCalendar)
            return .init(notificationRequested: observed.notificationRequested, calendarRequested: observed.calendarRequested)
        }, grant: grant)
    }

    private func titleEnvironment() throws -> TaskTitleCommandEnvironment {
        try .init(context: context, center: services.center, dependencies: .init(repository: { [unowned self] in tasks($0) },
            transaction: .init(), registerLocalModification: { _ in },
            requestReminderAccessIfNeeded: services.effects.requestReminderAccess),
            source: { [unowned self] _ in ordinarySource }, refresh: { [unowned self] _, calendar in refresh(calendar) },
            requestAuthorization: { [unowned self] in authorize($0) }, grant: grant)
    }

    private func subtaskEnvironment() throws -> SubtaskCommandEnvironment {
        try .init(context: context, center: services.center, dependencies: .init(repository: { [unowned self] in tasks($0) },
            transaction: .init(), registerLocalModification: { _ in }),
            source: { [unowned self] request in
                .init(parent: ordinarySource, subtask: request.target == nil ? nil : ordinaryProof, input: ordinaryProof)
            }, refresh: { [unowned self] _, calendar in refresh(calendar) }, grant: grant)
    }

    private func routineEnvironment() throws -> RoutineCommandEnvironment {
        try .init(context: context, center: services.center, dependencies: .init(repository: { [unowned self] in routines($0) },
            transaction: .init(), registerLocalModification: { _ in },
            requestReminderAccessIfNeeded: services.effects.requestReminderAccess),
            source: { [unowned self] _ in .init(target: ordinarySource, input: ordinaryProof) },
            refresh: { [unowned self] _, calendar in refresh(calendar) }, requestAuthorization: { [unowned self] in authorize($0) },
            creation: .init(now: services.now, calendar: services.calendar,
                            source: { [unowned self] _ in .init(input: ordinaryProof, environment: ordinaryProof) }),
            stateOperations: .init(now: services.now, calendar: services.calendar), grant: grant)
    }

    private func batchEnvironment() throws -> BatchCommandEnvironment {
        try .init(context: context, center: services.center,
                  dependencies: .init(tasks: tasks(context), routines: routines(context), transaction: .init()),
                  source: { [unowned self] _ in ordinarySource }, refresh: { [unowned self] _, calendar in refresh(calendar) },
                  stateOperations: .init(now: services.now, calendar: services.calendar), grant: grant)
    }

    private func clipboardEnvironment() throws -> ClipboardCaptureCommandEnvironment {
        let preferences = services.preferences, effects = services.effects
        var capture = ClipboardCapture.Environment.production(pasteboard: services.pasteboard, storage: services.attachments)
        capture.locale = { preferences.resolvedLocale }
        capture.today = services.today
        capture.sourceBundleID = effects.sourceBundleID
        let environment = try ClipboardCaptureCommandEnvironment(context: context, center: services.center, capture: capture,
            stampsSource: { preferences.stampCaptureApp }, transaction: .init(), grant: grant)
        environment.refresh = effects.refresh
        return environment
    }

    // MARK: - 简单指令规格（X-1 骨架的全部已实现消费者）

    private func simpleSpecs() -> [any SimpleCommandSpec] {
        let digest = coordinator.textDigest
        let task = TaskCommandDependencies(tasks: { [unowned self] in tasks($0) }, routines: { [unowned self] in routines($0) },
            source: { [unowned self] _ in ordinarySource },
            attachments: .init(store: services.attachments, root: writeRoot), today: services.today,
            requestReminderAccess: services.effects.requestReminderAccess, calendar: services.calendar, digest: digest)
        let diary = DiaryCommandDependencies(diaries: { [unowned self] in diaries($0) }, tasks: { [unowned self] in tasks($0) },
            attachments: .init(store: services.attachments, root: writeRoot), today: services.today,
            sourceBundleID: services.effects.sourceBundleID, digest: digest)
        let organize = TagOrganizeDependencies(diaries: { [unowned self] in diaries($0) },
                                               source: { [unowned self] _ in ordinarySource })
        return TaskCommandSpecs.all(task) + TaskCommandSpecs.longText(task) + BoardCommandSpecs.all(task)
            + TagCommandSpecs.all() + TagOrganizeSpecs.all(organize) + ImageCommandSpecs.all() + TrashRestoreSpec.all()
            + DiaryCommandSpecs.longText(diary) + DiaryCommandSpecs.organize(diary) + DiaryCommandSpecs.actions(diary)
    }
}
