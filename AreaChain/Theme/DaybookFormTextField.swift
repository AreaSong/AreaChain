import SwiftUI

/// 普通表单的公共呈现；原文和草稿由调用方持有，校验、提交与关闭仍属于宿主。
/// 使用 SwiftUI 原生单行输入，不接任务文本归并、语法解析或搜索会话。
struct DaybookFormTextField: View {
    @Binding private var text: String
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var isEnabled
    private let title: Text

    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.title = Text(title)
        _text = text
    }

    /// 已解析的本地化文字必须原样呈现，不能再次当资源键查找。
    init(verbatim title: String, text: Binding<String>) {
        self.title = Text(verbatim: title)
        _text = text
    }

    var body: some View {
        DaybookInputShell(kind: .search, focused: focused && isEnabled) {
            TextField(text: $text, prompt: title) { title }
                .textFieldStyle(.plain)
                .font(DaybookType.body)
                .foregroundStyle(isEnabled ? DaybookPalette.text.primary : DaybookPalette.text.tertiary)
                .focused($focused)
                .accessibilityLabel(title)
        }
    }
}
