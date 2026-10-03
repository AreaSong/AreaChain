import AppKit
import SwiftUI

/// AppKit 负责字段暂存、校验、时分进位及按键；桥接只在原生 action 时转换有效分钟。
struct DaybookNativeTimePicker: NSViewRepresentable {
    @Binding var minutes: Int?
    let title: String
    let status: String?
    let locale: Locale
    let calendar: Calendar
    @Binding var focused: Bool
    var eventVersion: UInt64?
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> DaybookTimeField {
        let field = DaybookTimeField()
        field.datePickerStyle = .textFieldAndStepper
        field.datePickerElements = .hourMinute
        field.datePickerMode = .single
        field.isContinuous = false
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: DaybookType.bodySize)
        field.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        context.coordinator.field = field
        field.target = context.coordinator
        field.action = #selector(Coordinator.changed(_:))
        field.onUserEvent = { [weak coordinator = context.coordinator] in coordinator?.beginInteraction() }
        return field
    }

    func updateNSView(_ field: DaybookTimeField, context: Context) {
        let coordinator = context.coordinator
        coordinator.synchronizeVersion(eventVersion, value: minutes)
        coordinator.binding = $minutes
        field.isEnabled = isEnabled
        field.textColor = NSColor(DaybookPalette.text.primary)
        field.setAccessibilityLabel(title)
        field.cell?.setAccessibilityLabel(title)
        field.toolTip = [title, status].compactMap { $0 }.joined(separator: " — ")
        field.setAccessibilityHelp(status)
        field.cell?.setAccessibilityHelp(status)
        let focus = $focused
        field.focusChanged = { value in
            // 焦点仅驱动外壳，不反向请求 first responder，也不在 SwiftUI 更新期间改状态。
            DispatchQueue.main.async { [weak coordinator] in
                guard coordinator?.binding != nil else { return }
                if focus.wrappedValue != value { focus.wrappedValue = value }
            }
        }
        coordinator.update(locale: locale, calendar: calendar)
    }

    static func dismantleNSView(_ field: DaybookTimeField, coordinator: Coordinator) {
        coordinator.binding = nil
        field.endLifetime()
        field.target = nil
        field.action = nil
        field.focusChanged = nil
        field.onUserEvent = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var field: DaybookTimeField?
        var binding: Binding<Int?>?
        private var presentation = DaybookTimePresentation(calendar: .current)
        private var locale: Locale?
        // 渲染戳只判断外部变化，绝不作为 setter 输入；nil 的外层表示从未挂载。
        private var rendered: Int??
        private var fallbackMinutes: Int?
        private var synchronizing = false
        private var eventVersion: UInt64?
        private var ownEcho: Int?
        private var staleInteraction = false

        /// 原生未完成时分只能属于开始编辑时的版本；外部草稿变化不能在失焦时补交旧值。
        func synchronizeVersion(_ version: UInt64?, value: Int?) {
            guard version != eventVersion else { return }
            defer { eventVersion = version; ownEcho = nil }
            guard version != nil, eventVersion != nil else { return }
            if let ownEcho, ownEcho == value { return }
            staleInteraction = true
            rendered = nil
        }

        func beginInteraction() {
            guard staleInteraction else { return }
            synchronizing = true
            readValue(force: true)
            synchronizing = false
            staleInteraction = false
        }

        func update(locale: Locale, calendar: Calendar) {
            guard let field, let binding else { return }
            let next = DaybookTimePresentation(calendar: calendar)
            let formatChanged = self.locale != locale || presentation.calendar != next.calendar
            let valueChanged = rendered == nil || rendered! != binding.wrappedValue
            presentation = next
            self.locale = locale
            synchronizing = true
            defer { synchronizing = false }
            if formatChanged {
                field.locale = locale
                field.calendar = presentation.calendar
                field.timeZone = presentation.calendar.timeZone
            }
            if valueChanged || formatChanged || !field.isEnabled {
                fallbackMinutes = RemindMinutes.from(date: .now, calendar: calendar)
                readValue()
            }
        }

        @objc func changed(_ sender: NSDatePicker) {
            guard !synchronizing, let field, sender === field,
                  field.acceptsActions, field.window?.isVisible == true, let binding else { return }
            guard field.isEnabled, !staleInteraction else { readValue(force: true); return }
            let next = presentation.minutes(field.dateValue)
            guard RemindMinutes.range.contains(next) else { return }
            ownEcho = next
            binding.wrappedValue = next
            // 同步回读拒绝/回滚结果；快照消费者随后通过原 SwiftUI 更新送达已保存值。
            readValue()
        }

        private func readValue(force: Bool = false) {
            guard let field, let binding else { return }
            let value = binding.wrappedValue
            rendered = .some(value)
            guard let minute = RemindMinutes.clamped(value) ?? fallbackMinutes,
                  let date = presentation.date(minute) else { return }
            // 不重复设置 dateValue，避免有效回声或无关刷新打断尚未完成的原生字段输入。
            if force || field.dateValue != date { field.dateValue = date }
        }
    }
}

final class DaybookTimeField: NSDatePicker {
    var focusChanged: ((Bool) -> Void)?
    var onUserEvent: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onUserEvent?()
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onUserEvent?()
        super.keyDown(with: event)
    }
    private(set) var acceptsActions = false
    private var closingObservers: [NSObjectProtocol] = []

    func endLifetime() {
        acceptsActions = false
        closingObservers.forEach(NotificationCenter.default.removeObserver)
        closingObservers.removeAll()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        // AppKit 可能在移除 responder 时完成字段；拆离前关闭提交资格，不能等 SwiftUI dismantle。
        if newWindow == nil { endLifetime() }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        acceptsActions = window != nil
        guard let window, closingObservers.isEmpty else { return }
        closingObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.acceptsActions = false }
        })
        closingObservers.append(NotificationCenter.default.addObserver(
            forName: NSPopover.willCloseNotification, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let popover = note.object as? NSPopover,
                      let root = popover.contentViewController?.view, self.isDescendant(of: root) else { return }
                // 弹出层关闭先于拆卸：不能让随后的 responder 释放补交暂存的单数字分钟。
                self.acceptsActions = false
            }
        })
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focusChanged?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { focusChanged?(false) }
        return accepted
    }
}
