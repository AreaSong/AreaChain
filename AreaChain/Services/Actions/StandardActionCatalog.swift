import Foundation
import SwiftData

/// 全软件标准 `BaseAction` 总装目录：统一汇聚全部业务动作族、注册进 `ActionRegistry`，并桥接 `DaybookActionDispatcher`。
@MainActor
enum StandardActionCatalog {
    private static var bootstrappedRegistries: Set<ObjectIdentifier> = []

    static func all(
        context: ModelContext? = nil,
        history: ActionHistoryStore? = nil,
        gateway: ExternalActionGateway? = nil
    ) -> [BaseAction] {
        WindowAndNavActions.all(history: history)
            + TaskMutationActions.all()
            + RoutineAndSubtaskActions.all()
            + PlanningBoardActions.all()
            + DiaryAndTagActions.all(context: context)
            + ClipboardAndTrashActions.all(context: context)
            + SettingsAndPrivacyActions.all(context: context)
            + [ExternalAccessPreferenceAction(gateway: gateway)]
    }

    static func registerAll(
        in registry: ActionRegistry? = nil,
        context: ModelContext? = nil,
        gateway: ExternalActionGateway? = nil
    ) {
        let targetRegistry = registry ?? .shared
        targetRegistry.register(
            all(
                context: context,
                history: targetRegistry.historyStore,
                gateway: gateway
            )
        )
    }

    /// 启动时幂等装配全局 `ActionRegistry.shared` 与 `DaybookActionDispatcher.shared`。
    static func bootstrapIfNeeded(
        registry: ActionRegistry? = nil,
        dispatcher: DaybookActionDispatcher? = nil
    ) {
        let targetRegistry = registry ?? .shared
        let targetDispatcher = dispatcher ?? .shared
        let registryKey = ObjectIdentifier(targetRegistry)
        if targetRegistry.allActions.count < 10 || !bootstrappedRegistries.contains(registryKey) {
            registerAll(in: targetRegistry)
            bootstrappedRegistries.insert(registryKey)
        }
        targetDispatcher.availabilityResolver = { rawID in
            let id = ActionID(rawValue: rawID)
            guard let action = targetRegistry.action(for: id) else {
                return (true, nil)
            }
            let context = ActionContext(isVaultUnlocked: PrivacyVault.shared.isUnlocked)
            switch action.availability(in: context) {
            case .available:
                return (true, nil)
            case .disabled(let reason):
                return (false, reason)
            case .requiresUnlock:
                let isZh = AppPreferences.shared.resolvedLocale.identifier.hasPrefix("zh")
                return (false, isZh ? "请先解锁隐私保护" : "Unlock Privacy Vault first")
            }
        }
        targetDispatcher.tooltipResolver = { rawID in
            let id = ActionID(rawValue: rawID)
            guard let action = targetRegistry.action(for: id) else { return nil }
            return action.localizedTitle(for: AppPreferences.shared.resolvedLocale)
        }
        targetDispatcher.fallbackExecutor = { rawID in
            let id = ActionID(rawValue: rawID)
            guard targetRegistry.action(for: id) != nil else { return }
            _ = targetRegistry.execute(
                id: id,
                context: ActionContext(isVaultUnlocked: PrivacyVault.shared.isUnlocked)
            )
        }
    }
}
