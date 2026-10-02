import SwiftUI

struct ClipboardHistoryOptions: View {
    @Bindable var session: ClipboardHistorySession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var pattern = ""
    @State private var typeName = ""
    @State private var patternRejected = false

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            HStack {
                Text("clipboard.options")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
                Button("alert.cancel") { dismiss() }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                    options
                }
            }
            .daybookScroll()
        }
        .padding(DaybookSpacing.lg)
        .frame(width: 440, height: 560)
        .background(DaybookPalette.fill.page)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            Toggle("clipboard.ignoreUniversal", isOn: Binding(
                get: { session.ignoreUniversal },
                set: { session.setIgnoreUniversal($0) }
            ))
            .toggleStyle(DaybookToggleStyle(.checkbox))
            .font(DaybookType.body)
            DaybookStepper(value: Binding(
                get: { session.limit },
                set: { session.setLimit($0) }
            ), in: ClipboardHistoryRules.minimumLimit...ClipboardHistoryRules.maximumLimit, step: 10) {
                Text("clipboard.limit \(session.limit)")
                    .font(DaybookType.body)
            }
            .accessibilityIdentifier("clipboard.limit")
            DaybookStepper(value: Binding(
                get: { session.interval },
                set: { session.setInterval($0) }
            ), in: ClipboardHistoryRules.minimumInterval...ClipboardHistoryRules.maximumInterval, step: 0.1) {
                Text(L10n.format("clipboard.interval", locale: locale, session.interval))
                    .font(DaybookType.body)
            }
            .accessibilityIdentifier("clipboard.interval")
            DaybookPicker("clipboard.searchMode", selection: Binding(
                get: { session.searchMode },
                set: { session.setSearchMode($0) }
            ), options: [
                .init(ClipboardSearchMode.mixed, "clipboard.searchMode.mixed"),
                .init(ClipboardSearchMode.exact, "clipboard.searchMode.exact"),
                .init(ClipboardSearchMode.regex, "clipboard.searchMode.regex")
            ])
            DaybookPicker("clipboard.panelAnchor", selection: Binding(
                get: { session.panelAnchor },
                set: { session.setPanelAnchor($0) }
            ), options: [
                .init(ClipboardPanelAnchor.cursor, "clipboard.panelAnchor.cursor"),
                .init(ClipboardPanelAnchor.center, "clipboard.panelAnchor.center")
            ])
            DaybookPicker("clipboard.clickAction", selection: Binding(
                get: { session.clickAction },
                set: { session.setClickAction($0) }
            ), options: [
                .init(ClipboardClickAction.copy, "clipboard.clickAction.copy"),
                .init(ClipboardClickAction.paste, "clipboard.clickAction.paste")
            ])
            Toggle("clipboard.plainByDefault", isOn: Binding(
                get: { session.plainByDefault },
                set: { session.setPlainByDefault($0) }
            ))
            .toggleStyle(DaybookToggleStyle(.checkbox))
            .font(DaybookType.body)
            Toggle("clipboard.playSound", isOn: Binding(
                get: { session.playSound },
                set: { session.setPlaySound($0) }
            ))
            .toggleStyle(DaybookToggleStyle(.checkbox))
            .font(DaybookType.body)
            Button("clipboard.ignoreNext") { session.armIgnoreNext() }
                .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
            listSection(title: "clipboard.ignoredApps", values: session.ignoredApps, remove: session.removeIgnoredApp)
            addRow(text: $pattern, placeholder: "clipboard.patterns.add", rejected: patternRejected) {
                patternRejected = !session.addPattern(pattern)
                if !patternRejected { pattern = "" }
            }
            listSection(title: "clipboard.patterns", values: session.patterns, remove: session.removePattern)
            addRow(text: $typeName, placeholder: "clipboard.types.add", rejected: false) {
                if session.addType(typeName) { typeName = "" }
            }
            listSection(title: "clipboard.types", values: session.extraTypes, remove: session.removeType)
            Text("clipboard.sealed.help")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listSection(title: LocalizedStringKey, values: [String], remove: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(title)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            if values.isEmpty {
                Text("clipboard.list.empty")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            } else {
                ForEach(values, id: \.self) { value in
                    HStack {
                        Text(value)
                            .font(DaybookType.body)
                            .foregroundStyle(DaybookPalette.text.primary)
                            .lineLimit(1)
                        Spacer()
                        DaybookIconButton(systemName: "xmark", label: "clipboard.remove", size: .inline) {
                            remove(value)
                        }
                    }
                }
            }
        }
    }

    private func addRow(
        text: Binding<String>,
        placeholder: LocalizedStringKey,
        rejected: Bool,
        add: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DaybookSpacing.sm) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(DaybookType.body)
            Button("clipboard.add", action: add)
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        }
        .overlay(alignment: .bottom) {
            if rejected {
                Text("clipboard.pattern.invalid")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        }
    }
}
