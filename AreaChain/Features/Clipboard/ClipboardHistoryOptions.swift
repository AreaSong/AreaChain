import SwiftUI

struct ClipboardHistoryOptions: View {
    @Bindable var session: ClipboardHistorySession
    @Environment(\.dismiss) private var dismiss
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
            Toggle("clipboard.ignoreUniversal", isOn: Binding(
                get: { session.ignoreUniversal },
                set: { session.setIgnoreUniversal($0) }
            ))
            .font(DaybookType.body)
            Stepper(value: Binding(
                get: { session.limit },
                set: { session.setLimit($0) }
            ), in: ClipboardHistoryRules.minimumLimit...ClipboardHistoryRules.maximumLimit, step: 10) {
                Text("clipboard.limit \(session.limit)")
                    .font(DaybookType.body)
            }
            Picker("clipboard.searchMode", selection: Binding(
                get: { session.searchMode },
                set: { session.setSearchMode($0) }
            )) {
                Text("clipboard.searchMode.mixed").tag(ClipboardSearchMode.mixed)
                Text("clipboard.searchMode.exact").tag(ClipboardSearchMode.exact)
                Text("clipboard.searchMode.regex").tag(ClipboardSearchMode.regex)
            }
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
            Spacer(minLength: 0)
        }
        .padding(DaybookSpacing.lg)
        .frame(width: 420, height: 520)
        .background(DaybookPalette.fill.page)
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
