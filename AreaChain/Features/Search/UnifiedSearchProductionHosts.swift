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

/// 菜单栏浮层中部：有查询或指令时显示结果与 CLI 面板。
struct MenuBarUnifiedSearchContent: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if controller.cliSession.shouldPresentPanel(for: controller.buffer.text) {
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menubar.unified.content")
    }

    static func showsOperation(_ controller: UnifiedSearchController) -> Bool {
        controller.cliSession.shouldPresentPanel(for: controller.buffer.text)
    }

    /// 浮层中部是否让位给搜索：有文字、在写指令或有活动面板。
    static func isActive(_ controller: UnifiedSearchController) -> Bool {
        !controller.buffer.text.isEmpty || controller.isCommandInput || showsOperation(controller)
    }
}

struct UnifiedSearchWorkspaceContent: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if controller.cliSession.shouldPresentPanel(for: controller.buffer.text) {
                UnifiedSearchCLIPanel(controller: controller)
            }
            if controller.showsNavigationFeedback {
                Text(LocalizedStringKey(controller.navigationMessage))
                    .font(DaybookType.caption)
                    .accessibilityIdentifier("unified.navigation.feedback")
            }
            UnifiedSearchResults(controller: controller)
                .unifiedSearchYieldsToCommand(controller)
        }
        .padding(DaybookSpacing.md)
        .background(DaybookPalette.fill.page)
    }
}

struct UnifiedSearchWorkspaceInput: View {
    @Bindable var controller: UnifiedSearchController
    var minimumWidth: CGFloat?
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    var body: some View {
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused,
                           actions: controller.actions, reset: controller.inputReset, showsStatus: false,
                           minimumWidth: minimumWidth, availableTags: Catalog.liveTags(tags).map(\.name))
    }
}

struct UnifiedSearchReturnBar: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        if let ticket = controller.returnSearch {
            HStack(spacing: DaybookSpacing.sm) {
                Button("unified.navigation.return") { Task { await controller.returnToSearch(ticket.id) } }
                    .buttonStyle(DaybookButtonStyle(.subtle))
                    .keyboardShortcut("[", modifiers: .command)
                    .accessibilityIdentifier("unified.navigation.return")
                if controller.showsNavigationMessage {
                    Text(LocalizedStringKey(controller.navigationMessage)).font(DaybookType.caption)
                }
                Spacer(minLength: 0)
            }
            .padding(DaybookSpacing.sm)
            .background(DaybookPalette.fill.page)
        }
    }
}

extension View {
    func unifiedSearchYieldsToCommand(_ controller: UnifiedSearchController) -> some View {
        let yields = controller.hidesResultsForCommand
        return opacity(yields ? 0 : 1)
            .allowsHitTesting(!yields)
            .accessibilityHidden(yields)
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
