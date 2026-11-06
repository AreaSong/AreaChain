import SwiftData
import SwiftUI

/// 工作台根视图：把唯一装配的工作台控制器与宿主交给 MainSplitWorkspaceView。
struct UnifiedSearchWorkspaceRoot: View {
    var production: UnifiedSearchProduction = .shared

    var body: some View {
        if let assembly = production.assembly, let controller = assembly.workspace {
            MainSplitWorkspaceView(navigation: assembly.services.navigation, search: controller,
                                   menubarSearch: assembly.menubar,
                                   hostContext: assembly.hostContext, presentsSearchOnAppear: false)
                .background { UnifiedSearchFocusShortcut(controller: controller) }
                .id(production.generation)
        } else {
            MainSplitWorkspaceView()
        }
    }
}

/// 统一搜索没有可用控制器（装配失败）时占住搜索框的位置。
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
        Button("") {
            controller.resumeForExplicitAction(source: controller.buffer)
            controller.requestInputFocus()
        }
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
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused, actions: controller.actions,
                           layout: .compact, reset: controller.inputReset, showsStatus: false,
                           minimumWidth: DaybookMetrics.Window.popoverFooterSearchMinWidth,
                           availableTags: Catalog.liveTags(tags).map(\.name))
            .environment(\.daybookChromelessWhenIdle, controller.buffer.text.isEmpty)
            .accessibilityIdentifier("menubar.unified.input")
    }
}

/// 菜单栏浮层中部：有查询或指令时显示结果与 CLI / 导航面板。
struct MenuBarUnifiedSearchContent: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if !controller.isNavigationInput, controller.cliSession.shouldPresentPanel(for: controller.buffer.text) {
                UnifiedSearchCLIPanel(controller: controller)
            }
            if controller.showsNavigationFeedback {
                Text(LocalizedStringKey(controller.navigationMessage))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("menubar.unified.feedback")
            }
            UnifiedSearchResults(controller: controller, layout: .compact)
                .unifiedSearchYieldsToCommand(controller)
            if Self.showsOperation(controller), !controller.hidesResultsForCommand {
                UnifiedSearchNavigationPanel(controller: controller)
                    .frame(height: 220)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menubar.unified.content")
    }

    static func showsOperation(_ controller: UnifiedSearchController) -> Bool {
        controller.isNavigationInput && controller.operationVisible
    }

    /// 浮层中部是否让位给搜索：有文字、在写指令或有活动面板。
    static func isActive(_ controller: UnifiedSearchController) -> Bool {
        !controller.buffer.text.isEmpty || controller.isCommandInput || showsOperation(controller)
    }
}

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
