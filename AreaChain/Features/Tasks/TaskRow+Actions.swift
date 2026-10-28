import AppKit
import SwiftUI

extension TaskRow {
    // MARK: - Actions & Editing

    var editor: some View {
        SyntaxTextField(
            text: $draft,
            placeholder: L10n.string("row.edit.field", locale: locale),
            focused: $editorFocused,
            allowsShiftNewline: true,
            onSubmit: saveEdit,
            onEscape: cancelEdit
        )
        .background(TaskRowEditorOutsideClickMonitor(onOutsideClick: commitEditOnBlur))
        .onAppear { DispatchQueue.main.async { editorFocused = true } }
        .onChange(of: editorFocused) { wasFocused, focused in
            if wasFocused, !focused, editing, hostContext?.isIsolated != true {
                commitEditOnBlur()
            }
        }
    }

    var timePicker: some View {
        DaybookTimePicker(
            "row.time",
            minutes: Binding(
                get: { state.remindMinutes },
                set: { dispatch(.setRemindMinutes($0)) }
            )
        )
        .environment(\.locale, locale)
        .padding(DaybookMetrics.TimePicker.popoverPadding)
        .frame(minWidth: DaybookMetrics.TimePicker.popoverMinimumWidth)
    }

    func beginEdit() {
        hasCopied = false
        draft = state.title
        editorFocused = false
        editing = true
    }

    func cancelEdit() {
        _ = boardSelection.consumeEscapeCancelsEdits()
        draft = state.title
        if hostContext != nil { editDrafts.titles.removeValue(forKey: navigationDraftKey) }
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    func commitEditOnBlur() {
        guard editing else { return }
        if boardSelection.consumeEscapeCancelsEdits() {
            cancelEdit()
        } else if draft == state.title {
            cancelEdit()
        } else {
            saveEdit()
        }
    }

    func saveEdit() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            if let onSaveTitle {
                guard onSaveTitle(next) else { return }
            } else {
                dispatch(.editTitle(next))
            }
        } else {
            draft = state.title
        }
        if hostContext != nil { editDrafts.titles.removeValue(forKey: navigationDraftKey) }
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    func copyTask() {
        guard copy(.record) else { return }
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasCopied = true
        }
    }

    @discardableResult func copyTitleInline() -> Bool {
        guard copy(.title) else { return false }
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasCopied = true
        }
        return true
    }

    @discardableResult func copyNoteInline() -> Bool {
        guard copy(.notes) else { return false }
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasNoteCopied = true
        }
        return true
    }

    /// 与 todo.copy 共用内容规则和写入接口；写入失败时不显示已复制。
    @discardableResult func copy(_ section: TaskCopySection) -> Bool {
        guard let text = TaskCopyContent.text(section, title: state.title, notes: fullNoteText) else { return false }
        return copyToClipboard(text)
    }

    @discardableResult func copyToClipboard(_ text: String) -> Bool {
        do {
            try (clipboardWriter ?? SystemClipboardTextWriter.shared).write(text)
            DaybookStatusNoticeCenter.shared.show(.copied)
            return true
        } catch { return false }
    }
}

/// 监听行内编辑框外部的鼠标按下事件：在点击非第一响应者区域（如顶栏、空白边距或复选框）时主动收起编辑并确认保存。
private struct TaskRowEditorOutsideClickMonitor: NSViewRepresentable {
    var onOutsideClick: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onOutsideClick: onOutsideClick) }

    func makeNSView(context: Context) -> NSView {
        let view = OutsideClickAnchorView()
        context.coordinator.observe(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onOutsideClick = onOutsideClick
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    private final class OutsideClickAnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    @MainActor
    final class Coordinator {
        var onOutsideClick: () -> Void
        private var monitor: Any?

        init(onOutsideClick: @escaping () -> Void) {
            self.onOutsideClick = onOutsideClick
        }

        func observe(_ view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak view] event in
                guard let self, let view else { return event }
                MainActor.assumeIsolated {
                    self.handleMouseDown(event, anchorView: view)
                }
                return event
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handleMouseDown(_ event: NSEvent, anchorView: NSView) {
            guard let window = anchorView.window, event.window === window,
                  let field = activeField(for: anchorView, in: window) else { return }
            let point = event.locationInWindow
            let fieldPoint = field.convert(point, from: nil)
            if field.bounds.contains(fieldPoint) { return }
            if isPointInsideSyntaxPopup(point, in: window.contentView) { return }
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self else { return }
                if let field, field.currentEditor() != nil {
                    field.window?.makeFirstResponder(nil)
                }
                self.onOutsideClick()
            }
        }

        private func activeField(for anchorView: NSView, in window: NSWindow) -> DaybookAppKitTextField? {
            let anchorRect = anchorView.convert(anchorView.bounds, to: nil).insetBy(dx: -4, dy: -4)
            if let textView = window.firstResponder as? NSTextView,
               let field = textView.delegate as? DaybookAppKitTextField,
               field.convert(field.bounds, to: nil).intersects(anchorRect) {
                return field
            }
            return findActiveField(in: window.contentView, intersecting: anchorRect)
        }

        private func findActiveField(in view: NSView?, intersecting rect: NSRect) -> DaybookAppKitTextField? {
            guard let view else { return nil }
            if let field = view as? DaybookAppKitTextField,
               field.currentEditor() != nil,
               field.convert(field.bounds, to: nil).intersects(rect) {
                return field
            }
            for subview in view.subviews {
                if let found = findActiveField(in: subview, intersecting: rect) {
                    return found
                }
            }
            return nil
        }

        private func isPointInsideSyntaxPopup(_ windowPoint: NSPoint, in view: NSView?) -> Bool {
            guard let view else { return false }
            if let id = view.identifier?.rawValue,
               id == "syntax.overlay.candidates" || id == "syntax.overlay.preview" || id == "syntax.overlay.attributes" {
                let localPoint = view.convert(windowPoint, from: nil)
                if view.bounds.contains(localPoint) { return true }
            }
            return view.subviews.contains { isPointInsideSyntaxPopup(windowPoint, in: $0) }
        }
    }
}

private struct ClipboardTextWriterKey: EnvironmentKey {
    static let defaultValue: (any ClipboardTextWriting)? = nil
}

extension EnvironmentValues {
    /// 只供测试替换为 fake；未注入时生产仍写系统通用剪贴板。
    var clipboardTextWriter: (any ClipboardTextWriting)? {
        get { self[ClipboardTextWriterKey.self] }
        set { self[ClipboardTextWriterKey.self] = newValue }
    }
}
