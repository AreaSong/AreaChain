import SwiftData
import SwiftUI

struct UnifiedSearchNavigationPanel: View {
    /// 带日期参数的看板导航与 inspector.day 共用同一个日期选择。
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
            if controller.showsNavigationMessage {
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
            // 菜单栏转交被挡：说明挡住的草稿与列表，就地给出放弃与回到列表。
            if controller.showsBlockedHandoff {
                UnifiedSearchUnsavedWork(controller: controller, headlineKey: "unified.handoff.blocked")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("unified.handoff.blocked")
            }
            UnifiedSearchResults(controller: controller)
                .unifiedSearchYieldsToCommand(controller)
            if MenuBarUnifiedSearchContent.showsOperation(controller), !controller.hidesResultsForCommand {
                // 要在结果里挑对象时上下分栏：面板至少 260pt、可随窗口伸展，内容过长在面板内滚动。
                UnifiedSearchOperationPanel(controller: controller)
                    .frame(minHeight: 260, maxHeight: .infinity)
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
        // `#` 候选沿旧顶栏搜索：全部存活标签。
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused,
                           actions: controller.actions, reset: controller.inputReset, showsStatus: false,
                           minimumWidth: minimumWidth, availableTags: Catalog.liveTags(tags).map(\.name))
    }
}

struct UnifiedSearchReturnBar: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            bar
            // 停在从搜索导航到的目的地时也给出完整的被挡说明（草稿名、放弃、回到列表），不只一行反馈。
            if controller.showsBlockedHandoff {
                UnifiedSearchUnsavedWork(controller: controller, headlineKey: "unified.handoff.blocked")
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("unified.handoff.blocked")
            }
        }
        .padding(DaybookSpacing.sm)
        .background(DaybookPalette.fill.page)
    }

    private var bar: some View {
        HStack(spacing: DaybookSpacing.sm) {
            if let ticket = controller.returnSearch {
                Button("unified.navigation.return") { Task { await controller.returnToSearch(ticket.id) } }
                    .buttonStyle(DaybookButtonStyle(.subtle))
                    .keyboardShortcut("[", modifiers: .command)
                    .accessibilityIdentifier("unified.navigation.return")
            }
            if !controller.showsBlockedHandoff {
                Text(LocalizedStringKey(controller.navigationMessage)).font(DaybookType.caption)
            }
            Spacer(minLength: 0)
        }
    }
}

extension UnifiedSearchController {
    /// 导航面板可见时它自己显示反馈，宿主顶部不再重复同一句；面板被门禁收起时仍由宿主显示。
    /// 转交被挡的说明块已写出同一句，也不重复。
    var showsNavigationFeedback: Bool {
        navigationMessage != "unified.navigation.hint" && !(isNavigationInput && operationVisible)
            && !showsBlockedHandoff
    }
}

extension View {
    /// 指令不取结果期间：结果区保持挂载（滚动与选择不丢）但隐藏，操作面板占用结果区整块空间。
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
