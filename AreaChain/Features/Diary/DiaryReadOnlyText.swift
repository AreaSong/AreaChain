import SwiftUI

/// 手记只读展示文本
struct DiaryReadOnlyText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DaybookType.body)
            .foregroundStyle(DaybookPalette.text.primary)
            .textSelection(.enabled)
    }
}
