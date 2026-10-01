import SwiftUI

/// 工作台「快捷键」页。全局热键和应用内命令都在这里重录，不放进设置页。
struct ShortcutsSettingsView: View {
    @Bindable var store: ShortcutStore
    @State private var markers: Set<String> = []

    @MainActor
    init(store: ShortcutStore? = nil) {
        self.store = store ?? .shared
    }

    var body: some View {
        DaybookPage(title: "tab.shortcuts", systemImage: "keyboard", minWidth: 420, minHeight: 560) {
            Form {
                Section {
                    Text("shortcut.page.help")
                        .font(DaybookType.subtitle)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("shortcut.page.scope")
                        .font(DaybookType.subtitle)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .systemPageMarker("shortcuts.scope")
                }
                ForEach(ShortcutGroup.allCases, id: \.titleKey) { group in
                    Section(LocalizedStringKey(group.titleKey)) {
                        ForEach(group.actions) { action in
                            ShortcutRecorder(action: action, store: store)
                                .systemPageMarker("shortcut.\(action.rawValue)")
                        }
                    }
                }
                Section {
                    Button("shortcut.resetAll") { store.resetAll() }
                        .buttonStyle(DaybookButtonStyle(.quiet))
                        .systemPageMarker("shortcuts.resetAll")
                }
            }
            .formStyle(.grouped)
            .daybookScroll()
            .systemPageMarkers($markers)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("shortcuts.page")
        .accessibilityValue(markers.sorted().joined(separator: " "))
    }
}
