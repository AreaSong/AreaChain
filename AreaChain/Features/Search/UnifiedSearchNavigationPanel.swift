import SwiftUI

struct UnifiedSearchNavigationPanel: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.calendar) private var calendar
    @State private var showsDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.navigation.hint").font(DaybookType.body)
            if controller.browsedCommand?.id.rawValue == "inspector.day" {
                Button("unified.navigation.chooseDay") { showsDate = true }
                    .buttonStyle(DaybookButtonStyle(.subtle))
                    .popover(isPresented: $showsDate) {
                        DaybookDatePicker(selection: Binding(get: {
                            let result = CommandPathParser().parse(.init(text: controller.buffer.text))
                            if case .day(let day)? = result.arguments.first?.value { return day }
                            return DayKey.today(calendar: calendar)
                        }, set: { key in
                            _ = controller.navigationInput("/inspector/day/" + key)
                            showsDate = false
                        }))
                        .padding(DaybookSpacing.md)
                    }
            }
            Text(LocalizedStringKey(controller.navigationMessage)).font(DaybookType.caption)
                .accessibilityIdentifier("unified.navigation.message")
            Button("unified.navigation.open") { controller.executeNavigation(source: controller.buffer) }
                .buttonStyle(DaybookButtonStyle(.prominent))
                .accessibilityIdentifier("unified.navigation.open")
        }
        .padding(DaybookSpacing.md)
    }
}

struct UnifiedSearchWorkspaceContent: View {
    @Bindable var controller: UnifiedSearchController
    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if controller.navigationMessage != "unified.navigation.hint" {
                Text(LocalizedStringKey(controller.navigationMessage))
                    .font(DaybookType.caption)
                    .accessibilityIdentifier("unified.navigation.feedback")
            }
            UnifiedSearchResults(controller: controller)
            if controller.isNavigationInput || controller.operations?.active != nil
                || controller.plan?.items.isEmpty == false || controller.settingExecution != nil {
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
    var body: some View {
        UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused,
                           actions: controller.actions, reset: controller.inputReset, showsStatus: false)
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
