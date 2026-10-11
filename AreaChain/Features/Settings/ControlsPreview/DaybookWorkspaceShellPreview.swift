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

/// 工作台左侧栏新增的独立预览页面（展示三大公用空间及右下第 3 块的两大公用子模式：滑动列表公用模式 & 固定一屏公用模式）。
struct WorkspaceShellPreviewPage: View {
    @Environment(\.locale) private var locale
    @WorkspaceNavigationContext private var navigation
    @State private var placeholderID = UUID()
    @State private var isScrollableMode = true
    @State private var previewDraft = ""
    @State private var previewFocused = false
    @State private var selectedFilterIndex = 0

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
            if isScrollableMode {
                scrollablePublicShellPreview
            } else {
                fixedPublicShellPreview
            }
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
        HStack(spacing: DaybookSpacing.sm) {
            DaybookChip(isSelected: isScrollableMode) {
                withAnimation(DaybookMotion.interactive) {
                    isScrollableMode.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isScrollableMode ? "scroll" : "rectangle.dashed")
                    Text(verbatim: isScrollableMode ? "滑动公用模式" : "固定一屏模式")
                }
            }

            HStack(spacing: DaybookSpacing.xs) {
                DaybookProgressRing(progress: 0, lineWidth: 2, size: DaybookMetrics.Hit.inline, showsPercentage: false)
                Text(verbatim: "0/3")
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
            }
        }
    }

    // MARK: - 模式二：滑动列表公用模式（公用单行录入槽 + 公用单行筛选槽 + 顶部 18pt 原生高斯模糊滚动槽）

    private var scrollablePublicShellPreview: some View {
        DaybookScrollablePageShell {
            DaybookComposer(
                text: $previewDraft,
                placeholder: L10n.string("workspace.composer.placeholder", locale: locale),
                focus: $previewFocused,
                onSubmit: { previewDraft = "" }
            )
        } filterBar: {
            HStack(spacing: DaybookSpacing.xs) {
                ForEach(Array(["昨天 3 ⌄", "全部", "#工作", "#生活"].enumerated()), id: \.offset) { index, label in
                    DaybookChip(isSelected: selectedFilterIndex == index) {
                        selectedFilterIndex = index
                    } label: {
                        Text(verbatim: label)
                    }
                }
                Spacer(minLength: DaybookSpacing.sm)
                ForEach(["标签 ⌄", "优先级 ⌄", "提醒 ⌄"], id: \.self) { label in
                    DaybookChip(isSelected: false, action: {}) {
                        Text(verbatim: label)
                    }
                }
            }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                    ForEach(1...12, id: \.self) { index in
                        scrollablePlaceholderRow(index: index)
                    }
                }
                .padding(.vertical, 2)
            }
            .daybookScroll(featherEdges: true)
        }
    }

    private func scrollablePlaceholderRow(index: Int) -> some View {
        HStack(spacing: DaybookSpacing.md) {
            Image(systemName: "circle")
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "公用滚动槽列表项 #\(index)（向上滑动体验筛选栏下方 18pt 原生渐进高斯模糊）")
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                Text(verbatim: "顶部「单行快速录入框 + 单行筛选条」常驻固定，仅列表区滚动并在交界处产生原生高斯模糊")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DaybookSpacing.md)
        .padding(.vertical, DaybookSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .fill(DaybookPalette.sidebarFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .strokeBorder(DaybookPalette.sidebarBorder, lineWidth: 1)
        )
    }

    // MARK: - 模式一：固定一屏公用模式（如四象限 / 日历 / 安排）

    private var fixedPublicShellPreview: some View {
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
                Text(verbatim: "模式一：固定一屏公用模式（无外层滚动、无顶部模糊，如四象限 / 日历）")
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                Text(verbatim: "点击右上角「固定一屏模式 / 滑动公用模式」胶囊可随时切换对比两种公用结构")
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
