import SwiftUI

/// 工作台「隐私与解锁」页。解锁弹窗仍使用 `PrivacyUnlockView`。
struct PrivacyUnlockSettingsView: View {
    var vault: PrivacyVault
    @State private var markers: Set<String> = []

    init(vault: PrivacyVault? = nil) {
        self.vault = vault ?? .shared
    }

    var body: some View {
        DaybookPage(title: "tab.privacy", systemImage: "lock", minWidth: 420, minHeight: 560) {
            Form {
                PrivacySettingsSection(vault: vault)
                Section("privacy.boundary.title") {
                    Text("privacy.boundary.body")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .systemPageMarker("privacy.boundary")
                }
            }
            .formStyle(.grouped)
            .daybookScroll()
            .systemPageMarkers($markers)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("privacy.unlock.settings")
        .accessibilityValue(markers.sorted().joined(separator: " "))
    }
}
