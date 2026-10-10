import AppKit
import SwiftUI

struct UnifiedSearchLongTextField: View {
    @Bindable var controller: UnifiedSearchController
    let draft: CommandDraft
    let parameter: CommandParameter
    let source: UnifiedSearchBuffer
    @Environment(\.locale) private var locale

    private var editing: UnifiedSearchLongTextEditing? {
        guard let editing = controller.longTextEditing, editing.draftID == draft.id,
              editing.parameter == parameter.id, editing.available else { return nil }
        return editing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(draft.protectedReference == nil ? "unified.longText.ordinary" : "unified.longText.protected")
                .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
            if let editing {
                DaybookPicker("unified.operation.mode", selection: Binding(get: { editing.operation }, set: {
                    controller.changeLongTextOperation($0, editing: editing)
                }), options: CommandFieldOperation.allCases.filter { parameter.operations.contains($0) }.map {
                    .init($0, verbatim: L10n.format("unified.operation.mode." + $0.rawValue, locale: locale))
                }, layout: .formRow, eventVersion: source.version)
                .disabled(editing.pending || editing.composing)
                .accessibilityIdentifier("unified.longText.mode")
                DaybookInputShell(kind: .editor, focused: editing.editor?.window?.firstResponder === editing.editor) {
                    UnifiedSearchLongTextNative(controller: controller, editing: editing,
                        label: L10n.format(parameter.id.nameKey, locale: locale))
                        .frame(height: DaybookMetrics.inputHeight * 4)
                }
                .id(editing.id)
                if editing.pending {
                    Text("unified.longText.pending").font(DaybookType.caption)
                    HStack {
                        Button("unified.longText.confirm") { editing.editor?.confirmPendingInput() }
                            .accessibilityIdentifier("unified.longText.confirm")
                        Button("unified.longText.cancelInput") { editing.editor?.cancelOperation(nil) }
                    }.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                } else if editing.composing {
                    Text("unified.longText.composing").font(DaybookType.caption)
                }
                Text(LocalizedStringKey(editing.message)).font(DaybookType.caption)
                Button("unified.longText.close") { controller.endLongText() }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            } else {
                Button(draft.protectedReference == nil ? "unified.longText.edit" : "unified.longText.restore") {
                    controller.beginLongText(parameter.id, source: source)
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.longText.open." + parameter.id.rawValue)
            }
            if draft.protectedReference == nil {
                Button("unified.longText.protect") { controller.protectLongText(source: source) }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            if let message = controller.longTextMessage { Text(LocalizedStringKey(message)).font(DaybookType.caption) }
        }
    }
}

private struct UnifiedSearchLongTextNative: NSViewRepresentable {
    let controller: UnifiedSearchController
    let editing: UnifiedSearchLongTextEditing
    let label: String

    func makeNSView(context: Context) -> NSScrollView {
        // 恢复发生在 makeNSView 内；零宽宿主会先按退化宽度排整篇，再在 SwiftUI 定尺寸时重排。
        // 初始宽度与专用 NSTextView 一致，实际宿主仍按原 autoresizing/widthTracksTextView 适配。
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: DaybookMetrics.inputHeight * 4))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.verticalScroller = DaybookScroller()
        scroll.autohidesScrollers = true
        let editor = CommandProtectedTextView(session: editing.content, parameter: editing.parameter)
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: DaybookSpacing.xs, height: DaybookSpacing.xs)
        editor.setAccessibilityIdentifier("unified.longText.editor." + editing.parameter.rawValue)
        configure(editor)
        scroll.documentView = editor
        do { try editing.attach(editor) }
        catch { editing.available = false; editing.message = "unified.longText.unavailable" }
        editor.onRevision = { [weak controller, weak editing] in
            guard let editing else { return }
            controller?.longTextAdvanced(editing)
        }
        editor.onEnd = { [weak editing] in editing?.available = false }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? CommandProtectedTextView else { return }
        configure(editor)
    }

    private func configure(_ editor: CommandProtectedTextView) {
        let font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        let color = NSColor(DaybookPalette.text.primary)
        if editor.font != font { editor.font = font }
        if editor.textColor != color { editor.textColor = color }
        if editor.insertionPointColor != color { editor.insertionPointColor = color }
        editor.setAccessibilityLabel(label)
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: ()) {
        (scroll.documentView as? CommandProtectedTextView)?.end()
    }
}
