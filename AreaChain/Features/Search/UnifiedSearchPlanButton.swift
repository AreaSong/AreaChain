import SwiftUI

/// 与现有对象选择按钮相同：释放空格时单次派发按下时的原版本回调。
struct UnifiedSearchPlanButton: View {
    let title: LocalizedStringKey
    let identifier: String
    var focusRevision: UInt64 = 0
    let action: () -> Void
    @FocusState private var focused: Bool
    @State private var pending: (() -> Void)?

    var body: some View {
        Button(title, action: action)
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            .focusable().focused($focused)
            .onKeyPress(.space, phases: [.down, .repeat, .up]) { press in
                guard focused, press.modifiers.isEmpty else { pending = nil; return .ignored }
                if press.phase == .down { pending = action }
                if press.phase == .up { let captured = pending; pending = nil; captured?() }
                return .handled
            }
            .onChange(of: focused) { _, value in if !value { pending = nil } }
            .onChange(of: focusRevision) { if focusRevision > 0 { focused = true } }
            .accessibilityIdentifier(identifier)
    }
}
