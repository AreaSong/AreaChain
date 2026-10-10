import AppKit
import SwiftUI

/// 控制工作台左侧边栏是否显示「重构预览（今日）」页面的开关状态（在「设置 → 界面与外观」中打开或关闭）。
@Observable
@MainActor
final class WorkspaceShellPreviewSettings {
    static let shared = WorkspaceShellPreviewSettings()
    private static let storageKey = "areachain.workspace.shellPreview.enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.storageKey)
            if !isEnabled && WorkspaceNavigation.shared.isShowingShellPreview {
                WorkspaceNavigation.shared.isShowingShellPreview = false
            }
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: Self.storageKey) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: Self.storageKey)
        }
    }
}

/// 工作台左侧栏新增的独立预览页面（展示三大公用空间：1. 左侧边栏、2. 右上固定顶栏、3. 右下主内容代码插入槽）。
struct WorkspaceShellPreviewPage: View {
    @Environment(\.locale) private var locale
    @WorkspaceNavigationContext private var navigation
    @State private var placeholderID = UUID()

    var body: some View {
        DaybookPage(
            title: "workspace.today.title",
            subtitleText: DayKey.displayName(DayClock.shared.todayKey, locale: locale),
            minWidth: 480,
            minHeight: 480,
            fullWidth: true
        ) {
            headerTrailing
        } content: {
            // =========================================================================
            // 👉 【第 3 块公用空间：右下主内容区（各页面代码插入槽）】
            // 开发具体页面时，在此处插入对应页面的主内容视图代码；
            // 左、右边界已与上方「第 2 块：右上固定顶栏」严格垂直对齐。
            // =========================================================================
            contentSlotPlaceholder
        }
        .workspaceHeader(actions: headerActions, status: AnyView(headerTrailing))
        .onAppear {
            navigation.updateInspectorTargets([placeholderID])
            if navigation.selectedTaskID == nil {
                navigation.selectedTaskID = placeholderID
            }
        }
    }

    private var headerActions: [WorkspaceHeaderAction] {
        [
            WorkspaceHeaderAction(
                id: "recurring",
                title: "workspace.recurring.menu",
                systemImage: "repeat",
                children: [
                    WorkspaceHeaderAction(id: "recurring.create", title: "recurring.create.open", systemImage: "plus") {},
                    WorkspaceHeaderAction(id: "recurring.manage", title: "workspace.residents.open", systemImage: "repeat") {}
                ]
            )
        ]
    }

    private var headerTrailing: some View {
        HStack(spacing: DaybookSpacing.xs) {
            DaybookProgressRing(progress: 0, lineWidth: 2, size: DaybookMetrics.Hit.inline, showsPercentage: false)
            Text(verbatim: "0/3")
                .font(DaybookType.caption.monospacedDigit())
                .foregroundStyle(DaybookPalette.text.primary)
        }
    }

    // MARK: - 第 3 块公用空间占位示意（后续按页讨论并在此插入各页面具体内容）

    private var contentSlotPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .fill(DaybookPalette.sidebarFill)
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .strokeBorder(
                    DaybookPalette.sidebarBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )

            VStack(spacing: DaybookSpacing.xs) {
                Image(systemName: "rectangle.dashed")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text(verbatim: "第 3 块：右下主内容区（各页面代码插入槽）")
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                Text(verbatim: "上方第 2 块（左标题 · 中搜索 · 右功能）已固定，左右边界上下严格对齐")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            .padding(DaybookSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 右侧检查器抽屉的颜色占位视图（在「重构预览（今日）」页内打开右侧抽屉时展示）。
struct WorkspaceShellInspectorPlaceholderView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .strokeBorder(
                    DaybookPalette.sidebarBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
            Text(verbatim: "右侧检查器抽屉插槽")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        }
        .padding(DaybookSpacing.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DaybookPalette.sidebarFill)
    }
}
