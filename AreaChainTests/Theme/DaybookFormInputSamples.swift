#if DEBUG
import SwiftUI
@testable import AreaChain

/// 沿原 ControlsPreview 展示；点击或 Tab 到达原生字段时显示公共聚焦外观。
struct DaybookFormInputSamples: View {
    @State private var name = ""
    @State private var pattern = #"^\(中文\) # @ ! // \s+$"#
    @State private var long = String(repeating: "普通输入 · Unicode 🧪 · common.save ", count: 12)

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("drawer.tag.create.name").font(DaybookType.title)
            DaybookFormTextField("drawer.tag.create.name", text: $name)
                .accessibilityIdentifier("preview.form.name")
            DaybookFormTextField("clipboard.patterns.add", text: $pattern)
                .accessibilityIdentifier("preview.form.pattern")
            DaybookFormTextField("clipboard.types.add", text: .constant("common.save")).disabled(true)
                .accessibilityIdentifier("preview.form.disabled")
            DaybookFormTextField(verbatim: "common.save", text: $long)
                .accessibilityIdentifier("preview.form.long")
            Button("dev.controls.toggle.external") { name = name.isEmpty ? "common.save" : "" }
                .buttonStyle(DaybookButtonStyle(.quiet))
        }
    }
}
#endif
