import SwiftData
import SwiftUI

/// 工作台根视图：把唯一装配的工作台控制器与宿主交给 MainSplitWorkspaceView。装配失败时仍是同一个工作台，
/// 只是顶栏搜索框换成不可用说明（见 UnifiedSearchUnavailableField）；重建装配时整棵重挂，旧控制器不留在视图里。
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

/// 统一搜索没有可用控制器（装配失败）时占住搜索框的位置：一句不阻塞的说明，悬停给出完整原因；不可编辑、不抢焦点。
struct UnifiedSearchUnavailableField: View {
    var compact = false

    var body: some View {
        DaybookInputShell(kind: .search, focused: false) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(DaybookPalette.text.secondary)
                .accessibilityHidden(true)
        } field: {
            Text(compact ? "search.unavailable.short" : "search.unavailable")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .help(Text("search.unavailable.help"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("search.unavailable.help"))
    }
}

extension UnifiedSearchController {
    /// 宿主主动把焦点交给输入框（⌘F、详情收起）。控制器初始 `inputFocused` 为真；输入框若从未真正拿到焦点
    /// （焦点被页面输入框先占），再置真不产生变化、也就不会请求焦点（先置假再置真会在渲染前被合并，同样无效）。
    /// 所以置真之外，输入框不在编辑时直接让它成为第一响应者；已在编辑时什么也不做，不打断选区与组合文本。
    func requestInputFocus() {
        inputFocused = true
        guard let field = inputReset.state?.field, field.currentEditor() == nil, let window = field.window else { return }
        window.makeFirstResponder(field)
    }
}

/// 搜索快捷键（默认 ⌘F，快捷键页可改或停用）聚焦统一搜索框。
struct UnifiedSearchFocusShortcut: View {
    let controller: UnifiedSearchController

    var body: some View {
        Button("") { controller.requestInputFocus() }
            .appShortcut(.search)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// 菜单栏底栏中间的新搜索框；尺寸沿紧凑布局，外观仍是 Daybook 搜索外壳。
struct MenuBarUnifiedSearchField: View {
    @Bindable var controller: UnifiedSearchController
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    var body: some View {
        // `#` 候选沿旧底栏搜索：全部存活标签（Catalog.liveTaskTags 与 liveTags 同义，修复批 M-7F）。
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused, actions: controller.actions,
                           layout: .compact, reset: controller.inputReset, showsStatus: false,
                           minimumWidth: DaybookMetrics.Window.popoverFooterSearchMinWidth,
                           availableTags: Catalog.liveTags(tags).map(\.name))
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

/// 把统一搜索的焦点与“正在搜索”接到菜单栏的 MenuBarToolbarState：快捷键、Esc、手记快捷键与
/// 列表键盘的判断都读 toolbar，这样不必逐处改写。装配失败（controller 为 nil）时没有可聚焦的输入，
/// ⌘F 等入口置起的搜索焦点立即撤回，列表键盘不会因此停用。
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
                guard let controller else {
                    if focused { toolbar.searchIsFocused = false }
                    return
                }
                if controller.inputFocused != focused { controller.inputFocused = focused }
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
