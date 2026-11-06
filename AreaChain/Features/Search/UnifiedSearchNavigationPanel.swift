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
            if controller.showsNavigationMessage {
                Text(LocalizedStringKey(controller.navigationMessage)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.navigation.message")
            }
            Button(openTitle) { controller.executeNavigation(source: controller.buffer) }
                .buttonStyle(DaybookButtonStyle(.prominent))
                .accessibilityIdentifier("unified.navigation.open")
        }
        .padding(DaybookSpacing.md)
    }

    private var openTitle: LocalizedStringKey {
        if controller.browsedCommand?.completesOnOriginalPage == true { return "unified.originalPage.open" }
        return "unified.navigation.open"
    }
}

struct UnifiedSearchWorkspaceContent: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if !controller.isNavigationInput, controller.cliSession.shouldPresentPanel(for: controller.buffer.text) {
                UnifiedSearchCLIPanel(controller: controller)
            }
            if controller.showsNavigationFeedback {
                Text(LocalizedStringKey(controller.navigationMessage))
                    .font(DaybookType.caption)
                    .accessibilityIdentifier("unified.navigation.feedback")
            }
            UnifiedSearchResults(controller: controller)
                .unifiedSearchYieldsToCommand(controller)
            if MenuBarUnifiedSearchContent.showsOperation(controller), !controller.hidesResultsForCommand {
                UnifiedSearchNavigationPanel(controller: controller)
                    .frame(minHeight: 260, maxHeight: .infinity)
            }
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
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            bar
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
    var showsNavigationFeedback: Bool {
        navigationMessage != "unified.navigation.hint" && !(isNavigationInput && operationVisible)
            && !showsBlockedHandoff
    }
}

extension View {
    func unifiedSearchYieldsToCommand(_ controller: UnifiedSearchController) -> some View {
        let yields = controller.hidesResultsForCommand
            && (controller.isNavigationInput || !controller.cliSession.shouldPresentPanel(for: controller.buffer.text))
        return opacity(yields ? 0 : 1)
            .allowsHitTesting(!yields)
            .accessibilityHidden(yields)
            .overlay(alignment: .top) {
                if yields, MenuBarUnifiedSearchContent.showsOperation(controller) {
                    UnifiedSearchNavigationPanel(controller: controller)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
    }
}
