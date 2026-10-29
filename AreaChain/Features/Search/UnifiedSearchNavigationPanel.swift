import SwiftData
import SwiftUI

struct UnifiedSearchNavigationPanel: View {
    /// 合并批 M-2：带日期参数的看板导航与 inspector.day 共用同一个日期选择。
    static let boardDayCommands: Set<String> = ["calendar.day", "calendar.dayList", "quadrant.day"]
    @Bindable var controller: UnifiedSearchController
    @Environment(\.calendar) private var calendar
    @State private var showsDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let route = controller.browsedCommand.flatMap({ CommandOriginalPage.route(for: $0.id) }) {
                UnifiedSearchOriginalPageBlock(controller: controller, route: route)
            } else if let action = controller.systemAction {
                UnifiedSearchSystemBlock(controller: controller, action: action)
            } else {
                Text("unified.navigation.hint").font(DaybookType.body)
            }
            if let command = controller.browsedCommand,
               ["inspector.day", "occurrence.inspect"].contains(command.id.rawValue)
                || UnifiedSearchNavigationPanel.boardDayCommands.contains(command.id.rawValue) {
                Button("unified.navigation.chooseDay") { showsDate = true }
                    .buttonStyle(DaybookButtonStyle(.subtle))
                    .popover(isPresented: $showsDate) {
                        DaybookDatePicker(selection: Binding(get: {
                            let result = CommandPathParser().parse(.init(text: controller.buffer.text))
                            if case .day(let day)? = result.arguments.first?.value { return day }
                            return DayKey.today(calendar: calendar)
                        }, set: { key in
                            _ = controller.navigationInput(command.path + "/" + key)
                            showsDate = false
                        }))
                        .padding(DaybookSpacing.md)
                    }
            }
            // 默认提示已由上方说明块给出，只在有执行反馈时再显示一行。
            if controller.navigationMessage != "unified.navigation.hint" {
                Text(LocalizedStringKey(controller.navigationMessage)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.navigation.message")
            }
            Button(openTitle) { controller.executeNavigation(source: controller.buffer) }
                .buttonStyle(DaybookButtonStyle(.prominent))
                .disabled(controller.systemActionBlocked)
                .accessibilityIdentifier("unified.navigation.open")
        }
        .padding(DaybookSpacing.md)
    }

    private var openTitle: LocalizedStringKey {
        if controller.browsedCommand?.completesOnOriginalPage == true { return "unified.originalPage.open" }
        return controller.systemAction == nil ? "unified.navigation.open" : "unified.system.run"
    }
}

struct UnifiedSearchWorkspaceContent: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if controller.showsNavigationFeedback {
                Text(LocalizedStringKey(controller.navigationMessage))
                    .font(DaybookType.caption)
                    .accessibilityIdentifier("unified.navigation.feedback")
            }
            UnifiedSearchResults(controller: controller)
                .unifiedSearchYieldsToCommand(controller)
            if MenuBarUnifiedSearchContent.showsOperation(controller), !controller.hidesResultsForCommand {
                UnifiedSearchOperationPanel(controller: controller)
                    .frame(height: 260)
            }
        }
        .padding(DaybookSpacing.md)
        .background(DaybookPalette.fill.page)
    }
}

struct UnifiedSearchWorkspaceInput: View {
    @Bindable var controller: UnifiedSearchController
    /// 顶栏按窗口宽度给出搜索宽度；宿主传入其下限，避免标准布局的 420pt 在最小窗口盖住标题区。
    var minimumWidth: CGFloat?
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    var body: some View {
        // `#` 候选沿旧顶栏搜索：全部存活标签（修复批 M-7F）。
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused,
                           actions: controller.actions, reset: controller.inputReset, showsStatus: false,
                           minimumWidth: minimumWidth, availableTags: Catalog.liveTags(tags).map(\.name))
    }
}

struct UnifiedSearchReturnBar: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        HStack(spacing: DaybookSpacing.sm) {
            if let ticket = controller.returnSearch {
                Button("unified.navigation.return") { Task { await controller.returnToSearch(ticket.id) } }
                    .buttonStyle(DaybookButtonStyle(.subtle))
                    .keyboardShortcut("[", modifiers: .command)
                    .accessibilityIdentifier("unified.navigation.return")
            }
            Text(LocalizedStringKey(controller.navigationMessage)).font(DaybookType.caption)
            Spacer(minLength: 0)
        }
        .padding(DaybookSpacing.sm)
        .background(DaybookPalette.fill.page)
    }
}

extension UnifiedSearchController {
    /// 导航面板可见时它自己显示反馈，宿主顶部不再重复同一句；面板被门禁收起时仍由宿主显示。
    var showsNavigationFeedback: Bool {
        navigationMessage != "unified.navigation.hint" && !(isNavigationInput && operationVisible)
    }
}

extension View {
    /// 不读结果的系统指令输入期间：结果区保持挂载（滚动与选择不丢）但隐藏，操作面板占用结果区整块空间。
    func unifiedSearchYieldsToCommand(_ controller: UnifiedSearchController) -> some View {
        let yields = controller.hidesResultsForCommand
        return opacity(yields ? 0 : 1)
            .allowsHitTesting(!yields)
            .accessibilityHidden(yields)
            .overlay(alignment: .top) {
                if yields, MenuBarUnifiedSearchContent.showsOperation(controller) {
                    UnifiedSearchOperationPanel(controller: controller)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
    }
}
