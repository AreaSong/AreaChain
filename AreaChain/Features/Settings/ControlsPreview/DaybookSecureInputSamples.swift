import SwiftUI

/// 合成安全输入仅在原 ControlsPreview 展示；原生遮蔽，无认证或提交动作。
struct DaybookSecureInputSamples: View {
    @State private var password = ""
    @State private var repeated = "synthetic-preview"
    @State private var long = String(repeating: "synthetic-🧪", count: 30)

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("privacy.master.label").font(DaybookType.title)
            DaybookSecureField("privacy.master.label", text: $password)
                .accessibilityIdentifier("preview.secure.password")
            DaybookSecureField("privacy.password.repeat", text: $repeated)
                .accessibilityIdentifier("preview.secure.repeat")
            DaybookSecureField("privacy.backup.password.title", text: .constant("synthetic-disabled")).disabled(true)
            DaybookSecureField("privacy.master.label", text: $long)
                .accessibilityIdentifier("preview.secure.long")
            Button("dev.controls.toggle.external") { password = ""; repeated = ""; long = "" }
                .buttonStyle(DaybookButtonStyle(.quiet))
        }
    }
}
