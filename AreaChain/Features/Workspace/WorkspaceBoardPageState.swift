import Foundation

/// 合并批 M-2：看板与标签页里原本放在页面 `@State` 的状态。只在显式宿主（WorkspaceHostContext）里由宿主持有，
/// 页面读写这一份、页面指令也只写这一份，不另存副本；默认生产入口和菜单栏仍用页面自己的 `@State`。
/// 离开对应页面即复位（见 WorkspaceNavigation.releasePageMemory），与页面卸载时 `@State` 重建一致。
struct WorkspaceBoardPageState: Equatable {
    var calendarSpan: CalendarSpan = .month
    /// 每递增一次，日历页执行一次“进入该日清单”（同 Return 键）；页面消费，不回写。
    var calendarListRequest = 0
    /// nil 表示页面初始的本月。
    var ganttMonth: String?
    var ganttSelection = TaskSelection()
    /// 安排页当前可见色块的屏幕顺序；范围选择只能沿这份顺序（TaskSelection 的规则）。由页面登记。
    var ganttOrder: [UUID] = []
}

/// 标签页的新建与改名草稿（G1 tag.cancel 取消的就是这两项）。
struct WorkspaceTagPageDrafts: Equatable {
    var createName = ""
    var renamingID: UUID?
    var renameName = ""

    var isEmpty: Bool { createName.isEmpty && renamingID == nil }
}
