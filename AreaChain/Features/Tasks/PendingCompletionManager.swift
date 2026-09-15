import SwiftUI

/// 任务与打卡完成的待沉底状态协调器：
/// 提供 0.4 秒防反悔驻留期，期间支持原地撤销；计时结束后平滑提交数据并沉底。
@Observable
@MainActor
final class PendingCompletionManager {
    static let shared = PendingCompletionManager()

    /// 当前正处于 0.4 秒驻留期内的任务或习惯 ID
    private(set) var pendingDoneIDs: Set<UUID> = []
    private var pendingTasks: [UUID: Task<Void, Never>] = [:]

    /// 检查指定任务当前在 UI 上是否应当呈现为“已完成”（综合考虑数据库状态与驻留期状态）
    func isVisuallyDone(id: UUID, actualDone: Bool) -> Bool {
        if actualDone { return true }
        return pendingDoneIDs.contains(id)
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// 切换任务完成状态（带驻留防反悔与平滑沉底）
    /// - Parameters:
    ///   - id: 任务或习惯 ID
    ///   - currentlyDone: 当前实际数据库状态是否已完成
    ///   - reduceMotion: 是否开启减弱动态效果
    ///   - onCommit: 真正持久化到数据库的操作
    func toggle(
        id: UUID,
        currentlyDone: Bool,
        reduceMotion: Bool = false,
        onCommit: @escaping @MainActor () -> Void
    ) {
        // 1. 如果当前已经在驻留期内，用户再次点击表示“反悔/撤回”
        if pendingDoneIDs.contains(id) {
            cancelPending(id)
            DaybookHaptics.tap()
            return
        }

        // 2. 如果本来就是实际已完成项（例如在已完成区域点击反勾选），直接恢复未完成
        if currentlyDone {
            onCommit()
            return
        }

        // 3. 如果在测试环境或开启了减弱动态效果，直接无延迟提交
        if isRunningTests || reduceMotion {
            onCommit()
            return
        }

        // 4. 正常未完成项点击完成：进入 0.4s 驻留期
        _ = withAnimation(DaybookMotion.checkmark) {
            pendingDoneIDs.insert(id)
        }

        let task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 秒
            guard !Task.isCancelled else { return }

            // 提交持久化，并伴随折叠动效沉底
            _ = withAnimation(DaybookMotion.collapse) {
                pendingDoneIDs.remove(id)
                onCommit()
            }
            pendingTasks.removeValue(forKey: id)
        }
        pendingTasks[id] = task
    }

    /// 取消某项的待沉底状态（用户在驻留期内反选）
    func cancelPending(_ id: UUID) {
        pendingTasks[id]?.cancel()
        pendingTasks.removeValue(forKey: id)
        _ = withAnimation(DaybookMotion.snappy) {
            pendingDoneIDs.remove(id)
        }
    }

    /// 清空所有待沉底任务（例如切换日期或退出页面时）
    func clearAll() {
        for (_, task) in pendingTasks {
            task.cancel()
        }
        pendingTasks.removeAll()
        pendingDoneIDs.removeAll()
    }
}
