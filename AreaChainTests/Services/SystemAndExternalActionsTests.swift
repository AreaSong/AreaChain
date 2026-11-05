import Foundation
import SwiftData
import XCTest
@testable import AreaChain

@MainActor
final class SystemAndExternalActionsTests: XCTestCase {
    private var container: ModelContainer!
    private var modelContext: ModelContext!
    private var historyStore: ActionHistoryStore!
    private var registry: ActionRegistry!
    private var defaultsSuiteName: String!
    private var testDefaults: UserDefaults!
    private var clipboardRoot: URL!
    private var clipboardSession: ClipboardHistorySession!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema(AreaChainSchema.models)
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        modelContext = container.mainContext
        historyStore = ActionHistoryStore.inMemory()
        registry = ActionRegistry(historyStore: historyStore)
        defaultsSuiteName = "areachain.system.actions.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)!
        clipboardRoot = FileManager.default.temporaryDirectory
            .appending(path: "areachain-clip-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        clipboardSession = ClipboardHistorySession(
            store: ClipboardHistoryStore(root: clipboardRoot), defaults: testDefaults, pasteboard: nil
        )
    }

    override func tearDown() async throws {
        if let defaultsSuiteName { UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName) }
        if let clipboardRoot { try? FileManager.default.removeItem(at: clipboardRoot) }
        container = nil; modelContext = nil; historyStore = nil
        registry = nil; testDefaults = nil; clipboardSession = nil
        try await super.tearDown()
    }

    private func makeContext(
        focusedID: UUID? = nil, isVaultUnlocked: Bool = true,
        confirmed: Bool = true, allowedPermission: ActionPermissionLevel = .system
    ) -> ActionContext {
        ActionContext(
            modelContext: modelContext, focusedObjectID: focusedID, todayKey: "2026-11-05",
            isVaultUnlocked: isVaultUnlocked, allowedExternalPermission: allowedPermission, confirmed: confirmed
        )
    }

    func testDiaryActionsExecuteUndoAndSensitivity() throws {
        registry.register(DiaryAndTagActions.all(context: modelContext))
        let ctx = makeContext()

        guard case .succeeded(_, let createDiff) = registry.executeCLI("/diary 今日复盘总结", context: ctx) else {
            return XCTFail("Expected diary.create to succeed")
        }
        XCTAssertEqual(createDiff?.isSensitive, false)
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<DiaryEntry>()).filter { $0.deletedAt == nil }.count, 1)
        XCTAssertNotNil(try historyStore.undo())
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<DiaryEntry>()).filter { $0.deletedAt == nil }.count, 0)
        XCTAssertNotNil(try historyStore.redo())

        guard case .succeeded(_, let secretDiff) = registry.executeCLI("/diary 招商银行卡密码 9527 #密码", context: ctx) else {
            return XCTFail("Expected sensitive diary.create to succeed")
        }
        XCTAssertEqual(secretDiff?.isSensitive, true)

        let publicEntry = try XCTUnwrap(try modelContext.fetch(FetchDescriptor<DiaryEntry>()).first { !$0.hasProtectedContent && $0.deletedAt == nil })
        let focusedCtx = makeContext(focusedID: publicEntry.id)
        _ = registry.executeCLI("/edit-diary --text 更新后的复盘", context: focusedCtx)
        XCTAssertEqual(publicEntry.text, "更新后的复盘")
        _ = try historyStore.undo()
        XCTAssertEqual(publicEntry.text, "今日复盘总结")

        _ = registry.executeCLI("/pin-diary", context: focusedCtx)
        XCTAssertTrue(publicEntry.isPinned)
        _ = try historyStore.undo()
        XCTAssertFalse(publicEntry.isPinned)

        _ = registry.executeCLI("/private-diary", context: focusedCtx)
        XCTAssertTrue(publicEntry.isPrivate)
        _ = try historyStore.undo()
        XCTAssertFalse(publicEntry.isPrivate)

        _ = registry.executeCLI("/diary-to-todo", context: focusedCtx)
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<TodoItem>()).filter { $0.deletedAt == nil }.count, 1)
        _ = try historyStore.undo()
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<TodoItem>()).filter { $0.deletedAt == nil }.count, 0)

        _ = registry.executeCLI("/rm-diary", context: focusedCtx)
        XCTAssertNotNil(publicEntry.deletedAt)
        _ = try historyStore.undo()
        XCTAssertNil(publicEntry.deletedAt)
    }

    func testAttachmentAndTagActionsExecuteAndUndoRedo() throws {
        registry.register(DiaryAndTagActions.all(context: modelContext))
        let ctx = makeContext()
        let todo = TodoItem(title: "带附件的待办", dayKey: "2026-11-05")
        let attachment = AttachmentItem(ownerKind: "todo", ownerID: todo.id, filename: "spec.pdf")
        modelContext.insert(todo); modelContext.insert(attachment)
        try modelContext.save()

        _ = registry.executeCLI("/rm-attachment spec.pdf", context: ctx)
        XCTAssertNotNil(attachment.deletedAt)
        _ = try historyStore.undo()
        XCTAssertNil(attachment.deletedAt)
        _ = try historyStore.redo()
        XCTAssertNotNil(attachment.deletedAt)
        _ = registry.executeCLI("/restore-attachment spec.pdf", context: ctx)
        XCTAssertNil(attachment.deletedAt)

        _ = registry.executeCLI("/tag 架构", context: ctx)
        _ = registry.executeCLI("/tag 临时", context: ctx)
        _ = registry.executeCLI("/tag 闲置标签", context: ctx)
        _ = registry.executeCLI("/rename-tag 架构 --to 核心架构", context: ctx)
        let renamedTag = try XCTUnwrap(Catalog.liveTags(try modelContext.fetch(FetchDescriptor<TagItem>())).first { $0.name == "核心架构" })
        _ = try historyStore.undo()
        XCTAssertEqual(renamedTag.name, "架构")
        _ = try historyStore.redo()
        XCTAssertEqual(renamedTag.name, "核心架构")

        _ = registry.executeCLI("/tag-color 核心架构 --color amber", context: ctx)
        XCTAssertEqual(renamedTag.colorToken, "amber")

        let tempTag = try XCTUnwrap(Catalog.liveTags(try modelContext.fetch(FetchDescriptor<TagItem>())).first { $0.name == "临时" })
        _ = DayBoardMutations.toggleTag(for: todo, tagID: tempTag.id)
        try modelContext.save()
        _ = registry.executeCLI("/merge-tag 临时 --into 核心架构", context: ctx)
        XCTAssertTrue(TagIDList.contains(todo.tagIDs, renamedTag.id))
        XCTAssertNotNil(tempTag.deletedAt)
        _ = try historyStore.undo()
        XCTAssertNil(tempTag.deletedAt)
        _ = try historyStore.redo()
        XCTAssertNotNil(tempTag.deletedAt)

        _ = registry.executeCLI("/clean-tags", context: ctx)
        let activeNames = Catalog.liveTags(try modelContext.fetch(FetchDescriptor<TagItem>())).map(\.name)
        XCTAssertFalse(activeNames.contains("闲置标签"))
        XCTAssertTrue(activeNames.contains("核心架构"))
        _ = try historyStore.undo()
        XCTAssertTrue(Catalog.liveTags(try modelContext.fetch(FetchDescriptor<TagItem>())).map(\.name).contains("闲置标签"))
    }

    func testClipboardAndTrashActionsExecuteAndUndoRedo() throws {
        registry.register(ClipboardAndTrashActions.all(context: modelContext, session: clipboardSession))
        let ctx = makeContext()
        clipboardSession.ingest(ClipboardHistoryDraft(
            plainText: "First Clip", html: nil, rtf: nil, png: nil,
            types: ["public.utf8-plain-text"], sourceBundleID: "com.test.app", copiedAt: Date(timeIntervalSince1970: 1_000)
        ))
        clipboardSession.ingest(ClipboardHistoryDraft(
            plainText: "Second Clip", html: nil, rtf: nil, png: nil,
            types: ["public.utf8-plain-text"], sourceBundleID: "com.test.app", copiedAt: Date(timeIntervalSince1970: 2_000)
        ))

        _ = registry.executeCLI("/clip-record", context: ctx)
        XCTAssertTrue(clipboardSession.isPaused)
        _ = try historyStore.undo()
        XCTAssertFalse(clipboardSession.isPaused)

        _ = registry.executeCLI("/clip-plain", context: ctx)
        XCTAssertTrue(clipboardSession.plainByDefault)
        _ = try historyStore.undo()
        XCTAssertFalse(clipboardSession.plainByDefault)

        _ = registry.executeCLI("/clip-pin \"Second Clip\"", context: ctx)
        XCTAssertTrue(clipboardSession.items.first { $0.plainText == "Second Clip" }?.isPinned == true)
        _ = registry.executeCLI("/clip-clear --confirm", context: ctx)
        XCTAssertEqual(clipboardSession.items.count, 1)
        _ = try historyStore.undo()
        XCTAssertEqual(clipboardSession.items.count, 2)

        _ = registry.executeCLI("/clip-rm \"First Clip\"", context: ctx)
        XCTAssertEqual(clipboardSession.items.count, 1)
        _ = try historyStore.undo()
        XCTAssertEqual(clipboardSession.items.count, 2)

        let deletedTodo = TodoItem(title: "待恢复任务", dayKey: "2026-11-05"); deletedTodo.deletedAt = Date()
        let purgeTarget = TodoItem(title: "待彻底删除任务", dayKey: "2026-11-05"); purgeTarget.deletedAt = Date()
        modelContext.insert(deletedTodo); modelContext.insert(purgeTarget); try modelContext.save()

        _ = registry.executeCLI("/restore 待恢复任务", context: ctx)
        XCTAssertNil(deletedTodo.deletedAt)
        _ = try historyStore.undo()
        XCTAssertNotNil(deletedTodo.deletedAt)
        _ = try historyStore.redo()
        XCTAssertNil(deletedTodo.deletedAt)

        _ = registry.executeCLI("/purge 待彻底删除任务 --confirm", context: ctx)
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<TodoItem>()).map(\.title), ["待恢复任务"])
        deletedTodo.deletedAt = Date(); try modelContext.save()
        _ = registry.executeCLI("/empty-trash --confirm", context: ctx)
        XCTAssertTrue(try modelContext.fetch(FetchDescriptor<TodoItem>()).isEmpty)
    }

    func testSettingsAndPrivacyActionsExecuteAndUndoRedo() throws {
        let prefs = AppPreferences(defaults: testDefaults)
        var counts = (unlock: 0, exportJSON: 0, importJSON: 0, exportBackup: 0, restoreBackup: 0)
        registry.register(SettingsAndPrivacyActions.all(
            preferences: prefs, context: modelContext,
            unlockHandler: { counts.unlock += 1; return true },
            exportJSONHandler: { _ in counts.exportJSON += 1; return URL(fileURLWithPath: "/tmp/out.json") },
            importJSONHandler: { _ in counts.importJSON += 1; return 3 },
            exportBackupHandler: { _ in counts.exportBackup += 1; return URL(fileURLWithPath: "/tmp/out.backup") },
            restoreBackupHandler: { _ in counts.restoreBackup += 1; return 5 }
        ))
        let ctx = makeContext()

        _ = registry.executeCLI("/theme dark", context: ctx)
        XCTAssertEqual(prefs.appearance, .dark)
        _ = try historyStore.undo(); XCTAssertEqual(prefs.appearance, .system)
        _ = try historyStore.redo(); XCTAssertEqual(prefs.appearance, .dark)

        _ = registry.executeCLI("/lang zh", context: ctx)
        XCTAssertEqual(prefs.language, .chinese)
        _ = try historyStore.undo(); XCTAssertEqual(prefs.language, .system)

        _ = registry.executeCLI("/truncation middle", context: ctx)
        XCTAssertEqual(prefs.contentTruncation, .middle)
        _ = try historyStore.undo(); XCTAssertEqual(prefs.contentTruncation, .tail)

        _ = registry.executeCLI("/cal-sync on", context: ctx)
        XCTAssertTrue(prefs.syncCalendarEvents)
        _ = try historyStore.undo(); XCTAssertFalse(prefs.syncCalendarEvents)

        _ = registry.executeCLI("/stamp-app on", context: ctx)
        XCTAssertTrue(prefs.stampCaptureApp)
        _ = try historyStore.undo(); XCTAssertFalse(prefs.stampCaptureApp)

        _ = registry.executeCLI("/lock", context: ctx)
        _ = registry.executeCLI("/unlock", context: ctx)
        _ = registry.executeCLI("/export-json", context: ctx)
        _ = registry.executeCLI("/import-json", context: ctx)
        _ = registry.executeCLI("/backup-export", context: ctx)
        _ = registry.executeCLI("/backup-restore --confirm", context: ctx)
        XCTAssertEqual(counts.unlock, 1)
        XCTAssertEqual(counts.exportJSON, 1)
        XCTAssertEqual(counts.importJSON, 1)
        XCTAssertEqual(counts.exportBackup, 1)
        XCTAssertEqual(counts.restoreBackup, 1)
    }

    func testExternalActionGatewayPoliciesAndURLSchemes() throws {
        let prefs = AppPreferences(defaults: testDefaults)
        registry.register(DiaryAndTagActions.all(context: modelContext))
        registry.register(ClipboardAndTrashActions.all(context: modelContext, session: clipboardSession))
        registry.register(SettingsAndPrivacyActions.all(
            preferences: prefs, context: modelContext,
            unlockHandler: { true }, exportJSONHandler: { _ in URL(fileURLWithPath: "/tmp/gateway.json") }
        ))
        let gateway = ExternalActionGateway(defaults: testDefaults, registry: registry, historyStore: historyStore)
        XCTAssertEqual(gateway.policy, .normalOnly)
        XCTAssertTrue(gateway.canExecute(.normal))
        XCTAssertFalse(gateway.canExecute(.privacy))
        XCTAssertFalse(gateway.canExecute(.system))

        let normalURL = try XCTUnwrap(URL(string: "areachain://action/pref.theme?args=dark"))
        let cliURL = try XCTUnwrap(URL(string: "areachain://cli?cmd=/diary%20GatewayNote"))
        let privacyURL = try XCTUnwrap(URL(string: "areachain://action/privacy.lock"))
        let systemURL = try XCTUnwrap(URL(string: "areachain://action/data.exportJSON"))

        XCTAssertTrue(gateway.execute(url: normalURL).succeeded)
        XCTAssertEqual(prefs.appearance, .dark)
        XCTAssertEqual(historyStore.appliedEntries.last?.diff.actionID, "pref.theme")
        XCTAssertTrue(gateway.execute(url: cliURL, context: makeContext()).succeeded)
        XCTAssertFalse(gateway.execute(url: privacyURL).succeeded)
        XCTAssertFalse(gateway.execute(url: systemURL).succeeded)

        gateway.policy = .disabled
        XCTAssertEqual(testDefaults.string(forKey: ExternalActionGateway.policyDefaultsKey), ExternalAccessPolicy.disabled.rawValue)
        XCTAssertFalse(gateway.canExecute(.normal))
        XCTAssertFalse(gateway.execute(url: normalURL).succeeded)
        XCTAssertFalse(gateway.execute(url: privacyURL).succeeded)
        XCTAssertFalse(gateway.execute(url: systemURL).succeeded)

        gateway.policy = .normalAndPrivacy
        XCTAssertTrue(gateway.canExecute(.normal))
        XCTAssertTrue(gateway.canExecute(.privacy))
        XCTAssertFalse(gateway.canExecute(.system))
        XCTAssertTrue(gateway.execute(url: normalURL).succeeded)
        XCTAssertTrue(gateway.execute(url: privacyURL).succeeded)
        XCTAssertFalse(gateway.execute(url: systemURL).succeeded)

        gateway.policy = .allIncludingSystem
        XCTAssertTrue(gateway.canExecute(.system))
        XCTAssertTrue(gateway.execute(url: systemURL).succeeded)
        let policyActionURL = try XCTUnwrap(URL(string: "areachain://action/pref.externalAccess?args=privacy"))
        XCTAssertTrue(gateway.execute(url: policyActionURL).succeeded)
        XCTAssertEqual(gateway.policy, .normalAndPrivacy)
        _ = try historyStore.undo()
        XCTAssertEqual(gateway.policy, .allIncludingSystem)
    }
}
