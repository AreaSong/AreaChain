import SwiftUI

/// 安全输入的公共呈现；密码只由宿主 Binding 持有，校验、提交和清空时机仍归宿主。
/// 保留原生 SecureField 的编辑与遮蔽承载，不维护密码镜像或扩展复制、撤销与明文显示能力。
struct DaybookSecureField: View {
    @Binding private var text: String
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var isEnabled
    private let title: Text
    private let autoFocus: Bool
    private let focusTrigger: Int

    init(_ title: LocalizedStringKey, text: Binding<String>, autoFocus: Bool = false, focusTrigger: Int = 0) {
        self.title = Text(title)
        _text = text
        self.autoFocus = autoFocus
        self.focusTrigger = focusTrigger
    }

    /// 已解析的本地化文字必须原样呈现，不能再次当资源键查找。
    init(verbatim title: String, text: Binding<String>, autoFocus: Bool = false, focusTrigger: Int = 0) {
        self.title = Text(verbatim: title)
        _text = text
        self.autoFocus = autoFocus
        self.focusTrigger = focusTrigger
    }

    var body: some View {
        DaybookInputShell(kind: .search, focused: focused && isEnabled) {
            SecureField(text: $text, prompt: title) { title }
                .textFieldStyle(.plain)
                .font(DaybookType.body)
                .foregroundStyle(isEnabled ? DaybookPalette.text.primary : DaybookPalette.text.tertiary)
                .focused($focused)
                .accessibilityLabel(title)
        }
        .onAppear {
            if autoFocus {
                DispatchQueue.main.async { focused = true }
            }
        }
        .onChange(of: focusTrigger) { _, _ in
            DispatchQueue.main.async { focused = true }
        }
    }
}
