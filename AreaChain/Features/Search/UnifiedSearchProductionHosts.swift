import SwiftUI

/// 合并批 M-6：工作台根视图。开关开时把唯一装配的工作台控制器与宿主交给原 MainSplitWorkspaceView；
/// 开关关时与改动前的入口完全相同（`MainSplitWorkspaceView()`：旧搜索、无显式宿主）。切换时整棵重挂，旧控制器不留在视图里。
struct UnifiedSearchWorkspaceRoot: View {
    var production: UnifiedSearchProduction = .shared

    var body: some View {
        if let assembly = production.assembly, let controller = assembly.workspace {
            MainSplitWorkspaceView(navigation: assembly.services.navigation, search: controller,
                                   hostContext: assembly.hostContext, presentsSearchOnAppear: false)
                .background { UnifiedSearchFocusShortcut(controller: controller) }
                .id(production.generation)
        } else {
            MainSplitWorkspaceView()
        }
    }
}

/// 搜索快捷键（默认 ⌘F，快捷键页可改或停用）聚焦新搜索框；与旧搜索框的 `.appShortcut(.search)` 同一入口。
struct UnifiedSearchFocusShortcut: View {
    let controller: UnifiedSearchController

    var body: some View {
        Button("") { controller.inputFocused = true }
            .appShortcut(.search)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// 菜单栏底栏中间的新搜索框；尺寸沿紧凑布局，外观仍是 Daybook 搜索外壳。
struct MenuBarUnifiedSearchField: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused, actions: controller.actions,
                           layout: .compact, reset: controller.inputReset, showsStatus: false,
                           minimumWidth: DaybookMetrics.Window.popoverFooterSearchMinWidth)
            .environment(\.daybookChromelessWhenIdle, controller.buffer.text.isEmpty)
            .accessibilityIdentifier("menubar.unified.input")
    }
}

/// 菜单栏浮层中部：有查询或指令时显示结果与操作面板，复用工作台同一组件。
struct MenuBarUnifiedSearchContent: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if controller.navigationMessage != "unified.navigation.hint" {
                Text(LocalizedStringKey(controller.navigationMessage))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("menubar.unified.feedback")
            }
            UnifiedSearchResults(controller: controller, layout: .compact)
            if Self.showsOperation(controller) {
                UnifiedSearchOperationPanel(controller: controller)
                    .frame(height: 220)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menubar.unified.content")
    }

    static func showsOperation(_ controller: UnifiedSearchController) -> Bool {
        controller.isNavigationInput || controller.operations?.active != nil
            || controller.plan?.items.isEmpty == false || controller.settingExecution != nil
    }

    /// 浮层中部是否让位给搜索：有文字、在写指令或有未完成的操作／计划。
    static func isActive(_ controller: UnifiedSearchController) -> Bool {
        !controller.buffer.text.isEmpty || controller.isCommandInput || showsOperation(controller)
    }
}

/// 把新搜索的焦点与“正在搜索”接到菜单栏原有的 MenuBarToolbarState：原有的快捷键、Esc、手记快捷键与
/// 列表键盘的判断都读 toolbar，这样不必逐处改写。
struct MenuBarUnifiedSearchBridge: ViewModifier {
    let controller: UnifiedSearchController?
    @Bindable var toolbar: MenuBarToolbarState

    func body(content: Content) -> some View {
        content
            .onChange(of: controller.map(MenuBarUnifiedSearchContent.isActive) ?? false, initial: true) { _, active in
                toolbar.unifiedActive = active
            }
            .onChange(of: controller?.inputFocused ?? false) { _, focused in
                if toolbar.searchIsFocused != focused { toolbar.searchIsFocused = focused }
            }
            .onChange(of: toolbar.searchIsFocused) { _, focused in
                if let controller, controller.inputFocused != focused { controller.inputFocused = focused }
            }
            // 浮层原有的焦点逻辑（打开时聚焦捕获框）为准：新控制器默认 inputFocused 为真，不能借此抢走焦点。
            .onAppear { if let controller, controller.inputFocused != toolbar.searchIsFocused {
                controller.inputFocused = toolbar.searchIsFocused } }
            .onChange(of: controller.map(ObjectIdentifier.init)) { _, _ in
                toolbar.unifiedActive = false
                controller?.inputFocused = toolbar.searchIsFocused
            }
    }
}

extension View {
    func menuBarUnifiedSearch(_ controller: UnifiedSearchController?, toolbar: MenuBarToolbarState) -> some View {
        modifier(MenuBarUnifiedSearchBridge(controller: controller, toolbar: toolbar))
    }
}
