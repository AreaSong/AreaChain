import Foundation
import Testing
@testable import AreaChain

@MainActor
private final class MockTaskMoveAction: BaseAction {
    var currentDate: String = "2026-11-05"

    init(
        permissionLevel: ActionPermissionLevel = .normal,
        riskLevel: ActionRiskLevel = .direct
    ) {
        super.init(
            id: "task.move",
            englishTitle: "Move Task Date",
            chineseTitle: "移动待办日期",
            commandNames: ["move", "mv", "移动", "改期"],
            iconName: "calendar",
            category: .task,
            parameters: [
                ActionParameterSpec(
                    id: "date",
                    englishName: "Date",
                    chineseName: "目标日期",
                    required: true,
                    defaultValue: "2026-11-06"
                ),
            ],
            permissionLevel: permissionLevel,
            riskLevel: riskLevel,
            recordsUndo: true
        )
    }

    override func perform(
        arguments: ParsedActionArguments,
        context: ActionContext
    ) throws -> ActionExecutionOutput {
        let target = arguments.targetQuery ?? context.focusedObjectTitle ?? "买牛奶"
        let oldDate = currentDate
        let newDate = arguments.value(for: "date", index: 0, defaultValue: "2026-11-06") ?? "2026-11-06"
        currentDate = newDate

        let diff = ActionDiff(
            actionID: id,
            actionTitle: chineseTitle,
            targetTitle: target,
            changes: [
                ActionFieldChange(field: "日期", before: oldDate, after: newDate),
            ],
            isSensitive: permissionLevel == .privacy
        )
        return ActionExecutionOutput(
            message: "已移动 \(target) 到 \(newDate)",
            diff: diff,
            undoPayload: ActionUndoPayload(
                actionID: id,
                snapshot: ["before": oldDate, "after": newDate]
            ),
            undoClosure: { [weak self] in
                self?.currentDate = oldDate
            },
            redoClosure: { [weak self] in
                self?.currentDate = newDate
            }
        )
    }
}

@Suite(.serialized)
@MainActor
struct ActionRegistryAndHistoryTests {
    @Test func registryCatalogExportPermissionGateAndConfirmationFlow() {
        let store = ActionHistoryStore.inMemory()
        let registry = ActionRegistry(historyStore: store)
        let dangerousDelete = MockTaskMoveAction(permissionLevel: .system, riskLevel: .confirm)
        registry.register(dangerousDelete)

        let groups = registry.exportedCatalogGroups()
        #expect(groups.contains { $0.category == .task })
        #expect(groups.contains { $0.category == .history })

        let restrictedContext = ActionContext(allowedExternalPermission: .normal, confirmed: false)
        let denied = registry.executeCLI("买牛奶 > move 2026-11-08", context: restrictedContext)
        #expect(denied == .permissionDenied(required: .system, allowed: .normal))

        let allowedUnconfirmedContext = ActionContext(allowedExternalPermission: .system, confirmed: false)
        let needsConfirm = registry.executeCLI("买牛奶 > move 2026-11-08", context: allowedUnconfirmedContext)
        if case .requiresConfirmation(let actionID, let prompt, _) = needsConfirm {
            #expect(actionID == "task.move")
            #expect(prompt.contains("买牛奶"))
        } else {
            Issue.record("预期返回二次确认状态")
        }
        #expect(dangerousDelete.currentDate == "2026-11-05")

        let confirmedStatus = registry.executeCLI("买牛奶 > move 2026-11-08 --confirm", context: allowedUnconfirmedContext)
        #expect(confirmedStatus.isSuccess)
        #expect(dangerousDelete.currentDate == "2026-11-08")
        #expect(store.appliedEntries.count == 1)
    }

    @Test func privacyLockRequiresUnlockBeforeExecutionAndUndo() {
        let store = ActionHistoryStore.inMemory()
        let registry = ActionRegistry(historyStore: store)
        let privateAction = MockTaskMoveAction(permissionLevel: .privacy, riskLevel: .direct)
        registry.register(privateAction)

        let lockedContext = ActionContext(isVaultUnlocked: false)
        let blocked = registry.executeCLI("/move 2026-11-09", context: lockedContext)
        #expect(blocked == .unavailable(.requiresUnlock))

        let unlockedContext = ActionContext(isVaultUnlocked: true)
        let ok = registry.executeCLI("/move 2026-11-09", context: unlockedContext)
        #expect(ok.isSuccess)

        let undoWhileLocked = registry.executeCLI("/undo", context: lockedContext)
        #expect(undoWhileLocked == .unavailable(.requiresUnlock))

        let historyWhileLocked = registry.executeCLI("/history", context: lockedContext)
        #expect(historyWhileLocked.message == ActionDiff.redactedPlaceholder)
    }

    @Test func bidirectionalUndoRedoAndHistoryQueryCommands() {
        let store = ActionHistoryStore.inMemory()
        let registry = ActionRegistry(historyStore: store)
        let moveAction = MockTaskMoveAction()
        registry.register(moveAction)
        let context = ActionContext(isVaultUnlocked: true)

        let first = registry.executeCLI("买牛奶 > 改期 2026-11-06", context: context)
        #expect(first.isSuccess)
        #expect(moveAction.currentDate == "2026-11-06")
        #expect(store.canUndo)
        #expect(!store.canRedo)

        let second = registry.executeCLI("买牛奶 > mv 2026-11-07", context: context)
        #expect(second.isSuccess)
        #expect(moveAction.currentDate == "2026-11-07")
        #expect(store.appliedEntries.count == 2)

        let undoStep1 = registry.executeCLI("/撤销", context: context)
        #expect(undoStep1.isSuccess)
        #expect(moveAction.currentDate == "2026-11-06")
        #expect(store.canUndo)
        #expect(store.canRedo)

        let undoStep2 = registry.executeCLI("/u", context: context)
        #expect(undoStep2.isSuccess)
        #expect(moveAction.currentDate == "2026-11-05")
        #expect(!store.canUndo)
        #expect(store.canRedo)

        let redoStep1 = registry.executeCLI("/下一步", context: context)
        #expect(redoStep1.isSuccess)
        #expect(moveAction.currentDate == "2026-11-06")

        let redoStep2 = registry.executeCLI("/r", context: context)
        #expect(redoStep2.isSuccess)
        #expect(moveAction.currentDate == "2026-11-07")
        #expect(!store.canRedo)

        let historyRes = registry.executeCLI("/历史 买牛奶", context: context)
        #expect(historyRes.isSuccess)
        #expect(historyRes.message?.contains("买牛奶：日期 2026-11-06 → 2026-11-07") == true)
    }

    @Test func diskPersistenceAcrossReloadAndRollingOneThousandLimit() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: "areachain-history-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let writerStore = ActionHistoryStore(
            fileURL: tempURL,
            maxCapacity: ActionHistoryStore.defaultMaxCapacity,
            persistToDisk: true
        )
        #expect(ActionHistoryStore.defaultMaxCapacity == 1000)

        for idx in 1...1005 {
            let diff = ActionDiff(
                actionID: "task.move",
                actionTitle: "移动待办日期",
                targetTitle: "任务-\(idx)",
                changes: [
                    ActionFieldChange(field: "序号", before: "\(idx - 1)", after: "\(idx)"),
                ]
            )
            writerStore.record(
                diff: diff,
                message: "完成 \(idx)",
                undoPayload: ActionUndoPayload(actionID: "task.move", snapshot: ["idx": "\(idx)"])
            )
        }

        #expect(writerStore.appliedEntries.count == 1000)
        #expect(writerStore.appliedEntries.first?.diff.targetTitle == "任务-6")
        #expect(writerStore.appliedEntries.last?.diff.targetTitle == "任务-1005")

        _ = try writerStore.undo()
        #expect(writerStore.appliedEntries.count == 999)
        #expect(writerStore.undoneEntries.count == 1)

        let reloadedStore = ActionHistoryStore(
            fileURL: tempURL,
            maxCapacity: ActionHistoryStore.defaultMaxCapacity,
            persistToDisk: true
        )
        #expect(reloadedStore.appliedEntries.count == 999)
        #expect(reloadedStore.undoneEntries.count == 1)
        #expect(reloadedStore.appliedEntries.first?.diff.targetTitle == "任务-6")
        #expect(reloadedStore.undoneEntries.last?.diff.targetTitle == "任务-1005")

        var redoneFromPayload = ""
        reloadedStore.payloadRedoHandler = { payload, _ in
            redoneFromPayload = payload.snapshot["idx"] ?? ""
        }
        let redoneDiff = try reloadedStore.redo()
        #expect(redoneDiff.targetTitle == "任务-1005")
        #expect(redoneFromPayload == "1005")
        #expect(reloadedStore.appliedEntries.count == 1000)
    }
}
