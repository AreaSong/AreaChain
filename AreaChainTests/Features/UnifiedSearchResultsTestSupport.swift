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

    init(_ batch: ContentQueryBatch = UnifiedSearchResultsFixture.mixed(), pageSize: Int = 3) throws {
        self.batch = batch
        handoff = try .init(sourcePage: .overview)
        let text = try QuerySessionFixture.source(batch.session)
        try handoff.send(.query(.setInput(text)))
        for condition in batch.session.conditions where condition.value == .scope(.routineOccurrences) {
            try handoff.send(.query(.addCondition(condition.value)))
        }
        session = try .init(vault: vault, owner: ContentQueryReadOwner(
            paginationPolicy: .init(units: pageSize, members: pageSize, contexts: pageSize)),
            coordinator: handoff.coordinator, ownership: handoff.owned().lease.ownership,
            notifications: .init(privacy: .default, model: model, focus: focus,
                focusLost: Self.focusLost, focusObject: focusObject))
        session.install()
        controller = UnifiedSearchController(session: session, coordinator: handoff.coordinator,
            buffer: .init(lease: try handoff.owned().lease, version: 0, text: text),
            read: { [weak self] in
                guard let self else { throw ContentQueryReadSessionError.detached }
                return try await self.publish()
            }, recordOpen: { [weak self] in self?.opens.append($0) })
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
