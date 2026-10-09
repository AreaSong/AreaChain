import AppKit
import SwiftUI
import Testing
@testable import AreaChain

struct UnifiedSearchResultsTestContent: View {
    @Bindable var controller: UnifiedSearchController
    let layout: UnifiedSearchInputLayout
    var body: some View {
        VStack(spacing: 8) {
            // 给唯一上方补全留出可用空间；下方始终是查询上下文，不是操作预览。
            Color.clear.frame(height: 320)
            UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused,
                actions: controller.actions, layout: layout, reset: controller.inputReset)
            UnifiedSearchResults(controller: controller, layout: layout)
        }
        .padding(12).background(DaybookPalette.fill.page).unifiedSearchOverlayHost()
    }
}

@MainActor
final class UnifiedSearchResultsFixture {
    let handoff: HandoffFixture
    let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
    let focus = NotificationCenter()
    let model = NotificationCenter()
    let focusObject = NSObject()
    let session: ContentQueryReadSession
    var batch: ContentQueryBatch
    var reads = 0
    var opens: [ContentQueryBrowseOpen] = []
    var controller: UnifiedSearchController!
    static let focusLost = Notification.Name("synthetic.results.focusLost")

    init(_ batch: ContentQueryBatch = UnifiedSearchResultsFixture.mixed(), pageSize: Int = 3,
         localPreferences: AppPreferences? = nil, filePreferences: AppPreferences? = nil,
         hostID: String = HandoffFixture.source, taskCreateEnvironment: TaskCreateCommandEnvironment? = nil,
         taskCreateCapability: TaskCreateCommandAdapter.Capability = .minimal,
         privacyCenter: NotificationCenter? = nil, taskTitleEnvironment: TaskTitleCommandEnvironment? = nil,
         taskFieldEnvironment: TaskTitleCommandEnvironment? = nil,
         taskFieldCapability: TaskFieldCommandAdapter.Capability = .basic, taskChainIO: TaskChainCommandIO? = nil,
         subtaskEnvironment: SubtaskCommandEnvironment? = nil, routineEnvironment: RoutineCommandEnvironment? = nil, batchEnvironment: BatchCommandEnvironment? = nil,
         enableMultiPlan: Bool = false, outputCapability: CommandMultiPlanOutputCapability = .taskTitle) throws {
        self.batch = batch
        handoff = try .init(sourcePage: .overview)
        let text = try QuerySessionFixture.source(batch.session)
        try handoff.send(.query(.setInput(text)), host: hostID)
        for condition in batch.session.conditions where condition.value == .scope(.routineOccurrences) {
            try handoff.send(.query(.addCondition(condition.value)), host: hostID)
        }
        session = try .init(vault: vault, owner: ContentQueryReadOwner(
            paginationPolicy: .init(units: pageSize, members: pageSize, contexts: pageSize)),
            coordinator: handoff.coordinator, ownership: handoff.owned(hostID).lease.ownership,
            notifications: .init(privacy: privacyCenter ?? .default, model: model, focus: focus,
                focusLost: Self.focusLost, focusObject: focusObject))
        session.install()
        let backend: UnifiedSearchSettingBackend
        if let filePreferences {
            precondition(localPreferences == nil)
            backend = .file(try FileLocalSettingCommandAdapter(coordinator: handoff.coordinator, filePreferences: filePreferences))
        } else {
            backend = localPreferences.map { .legacy(LocalSettingCommandAdapter(coordinator: handoff.coordinator, preferences: $0)) }
                ?? .unassembled
        }
        let creation = taskChainIO?.createEnvironment ?? taskCreateEnvironment
        let modification = taskChainIO?.titleEnvironment ?? taskTitleEnvironment
        let createAdapter = creation.map {
            TaskCreateCommandAdapter(coordinator: handoff.coordinator, environment: $0, capability: taskCreateCapability)
        }
        let titleAdapter = modification.map { TaskTitleCommandAdapter(coordinator: handoff.coordinator, environment: $0) }
        let chainAdapter = taskChainIO.flatMap { _ in
            createAdapter.flatMap { create in titleAdapter.map { TaskChainCommandAdapter(create: create, title: $0) } }
        }
        let fieldAdapter = taskFieldEnvironment.map { TaskFieldCommandAdapter(coordinator: handoff.coordinator,
                                                                              environment: $0, capability: taskFieldCapability) }
        let subtaskAdapter = subtaskEnvironment.map { SubtaskCommandAdapter(coordinator: handoff.coordinator, environment: $0) }
        let routineAdapter = routineEnvironment.map { RoutineCommandAdapter(coordinator: handoff.coordinator, environment: $0) }
        let batchAdapter = batchEnvironment.map { BatchCommandAdapter(coordinator: handoff.coordinator, environment: $0) }
        var multiAdapters = MultiPlanCommandAdapter.Adapters(taskCreate: createAdapter, taskTitle: titleAdapter,
            taskField: fieldAdapter, subtask: subtaskAdapter, routine: routineAdapter, batch: batchAdapter)
        if case .file(let adapter) = backend { multiAdapters.fileSettings = adapter }
        if case .legacy(let adapter) = backend { multiAdapters.localSettings = adapter }
        let multi = enableMultiPlan ? MultiPlanCommandAdapter(coordinator: handoff.coordinator, adapters: multiAdapters,
                                                              outputCapability: outputCapability) : nil
        controller = UnifiedSearchController(session: session, coordinator: handoff.coordinator,
            buffer: .init(lease: try handoff.owned(hostID).lease, version: 0, text: text),
            read: { [weak self] in
                guard let self else { throw ContentQueryReadSessionError.detached }
                return try await self.publish()
            }, recordOpen: { [weak self] in self?.opens.append($0) },
            settingBackend: backend, taskCreate: createAdapter, taskTitle: titleAdapter,
            taskField: fieldAdapter,
            taskChain: chainAdapter,
            subtask: subtaskAdapter, routine: routineAdapter, batch: batchAdapter, multiPlan: multi)
    }

    func publish() async throws -> ContentQueryReadEffect {
        reads += 1
        let handle = try session.prepare { query in QueryBatchFixture.replacingSession(batch, query) }
        try session.evaluate(handle)
        return try await session.publish(handle)
    }

    var page: ContentQueryPaginationState { get throws { try session.presentation().pagination } }

    func stop() { controller.detach() }

    nonisolated static func mixed() -> ContentQueryBatch {
        var batch = QueryBatchFixture.mixed("")
        batch.snapshots.diaries = .complete([.init(id: QueryBatchFixture.id, text: "", dayKey: QuerySessionFixture.today,
            createdAt: TodoQueryFixture.created, tagIDs: QueryBatchFixture.id.uuidString, isPrivate: true, isContentAvailable: false)])
        batch.facts.metadata = .init(tagNames: [QueryBatchFixture.id: "合成超长标签 multilingual résumé label"], privateTagIDs: [])
        return batch
    }

    nonisolated static func longText() -> ContentQueryBatch {
        QuerySortFixture.batch("needle", titles: [
            ("needle 👨‍👩‍👧‍👦 中文 e\u{301} " + String(repeating: "长标题 long title ", count: 20),
             String(repeating: "needle 合成摘要 👨‍👩‍👧‍👦 résumé. ", count: 60))])
    }
}

extension UnifiedSearchTestHost {
    func resultNode(_ identifier: String) throws -> NSObject {
        let nodes = SettingsButtonTestSupport.elements(window.contentView)
        let node = nodes.first { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == identifier }
        if node == nil {
            let dump = nodes.map { item in
                ["accessibilityRole", "accessibilityIdentifier", "accessibilityLabel"].map {
                    String(describing: SettingsButtonTestSupport.value(item, $0) ?? "-")
                }.joined(separator: " | ")
            }.joined(separator: "\n")
            try dump.write(to: FileManager.default.temporaryDirectory.appending(path: "unified-results-missing.txt"),
                           atomically: true, encoding: .utf8)
            try snapshot("results-missing")
        }
        return try #require(node, "缺少原生控件 \(identifier)")
    }

    func clickResult(_ identifier: String) async throws {
        let node = try resultNode(identifier)
        try await SettingsButtonTestSupport.reveal(node, in: window)
        try await SettingsButtonTestSupport.click(node, in: window)
    }
}
