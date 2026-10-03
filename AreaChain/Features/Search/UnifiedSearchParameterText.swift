import SwiftUI

/// 复用原输入的独立 field editor、组合文本、选区和 UndoManager；参数上下文禁用查询高亮。
struct UnifiedSearchParameterText: View {
    let controller: UnifiedSearchController
    let context: UnifiedSearchParameterContext
    let buffer: UnifiedSearchBuffer
    @Environment(\.locale) private var locale
    @State private var focused = false
    @State private var state: UnifiedSearchInputState

    init(controller: UnifiedSearchController, context: UnifiedSearchParameterContext, buffer: UnifiedSearchBuffer) {
        self.controller = controller
        self.context = context
        self.buffer = buffer
        _state = State(initialValue: .init(buffer: buffer, actions: Self.actions(controller, context)))
    }

    private static func actions(_ controller: UnifiedSearchController, _ context: UnifiedSearchParameterContext) -> UnifiedSearchActions {
        .init(edit: { controller.editParameterText($0, context: context) },
              accept: { controller.editParameterText($0, context: context) }, focus: { _ in }, intent: { intent, source in
            guard controller.validatesParameterSource(source, parameter: context.parameter.id) else { return }
            if intent == .submit { controller.requestOperationSubmit(controller.buffer) }
            // Return 确认已经校验的当前要素；Esc 返回输入，不删除参数。
            if intent == .escape { controller.inputFocused = true }
        })
    }

    var body: some View {
        DaybookInputShell(kind: .search, focused: focused) {
            DaybookTextField(text: .constant(buffer.text), placeholder: L10n.format(context.parameter.id.nameKey, locale: locale),
                focus: $focused, onSubmit: {}, onCommandReturn: {},
                commandChord: .init(keyCode: ShortcutKey.returnKey, modifiers: ShortcutModifier.command),
                allowsShiftNewline: false, unifiedSearch: state, searchBuffer: buffer,
                searchConfiguration: .init(actions: Self.actions(controller, context), parser: .init(),
                    discovery: .standard, locale: locale, parameter: context))
                .accessibilityLabel(Text(verbatim: L10n.format(context.parameter.id.nameKey, locale: locale)))
                .accessibilityIdentifier("unified.parameter.text." + context.parameter.id.rawValue)
        }
        .onDisappear { state.end() }
    }
}
