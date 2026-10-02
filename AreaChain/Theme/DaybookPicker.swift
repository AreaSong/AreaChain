import AppKit
import SwiftUI

/// 业务身份独立于翻译及排列；同一选择器内 value 必须唯一。
struct DaybookPickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String.LocalizationValue
    var id: Value { value }

    init(_ value: Value, _ label: String.LocalizationValue) {
        self.value = value
        self.label = label
    }
}

/// Binding 是唯一选中状态；公共层不保存偏好，也不在挂载或选项缺失时纠正业务值。
struct DaybookPicker<Value: Hashable>: View {
    let title: String.LocalizationValue
    @Binding var selection: Value
    let options: [DaybookPickerOption<Value>]
    @Environment(\.locale) private var locale

    init(_ title: String.LocalizationValue, selection: Binding<Value>, options: [DaybookPickerOption<Value>]) {
        self.title = title
        _selection = selection
        self.options = options
    }

    var body: some View {
        HStack(spacing: DaybookMetrics.Picker.labelSpacing) {
            Text(verbatim: L10n.string(title, locale: locale))
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            DaybookNativePicker(title: L10n.string(title, locale: locale), selection: $selection,
                options: options.map { ($0.value, L10n.string($0.label, locale: locale)) },
                unavailable: L10n.string(options.isEmpty ? "picker.empty" : "picker.unavailable", locale: locale))
                .daybookMenuLabel(size: .regular, fitsLabel: true)
                .disabled(options.isEmpty)
        }
    }
}

private struct DaybookNativePicker<Value: Hashable>: NSViewRepresentable {
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]
    let unavailable: String
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.font = .systemFont(ofSize: DaybookType.bodySize)
        button.contentTintColor = NSColor(DaybookPalette.text.secondary)
        button.menu = NSMenu()
        button.cell?.lineBreakMode = .byTruncatingTail
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.selection = $selection
        coordinator.unavailable = unavailable
        button.setAccessibilityLabel(title)
        button.cell?.setAccessibilityLabel(title)
        button.isEnabled = isEnabled && !options.isEmpty
        if !coordinator.matches(options) {
            coordinator.options = options
            coordinator.rebuildMenu()
        }
        coordinator.readSelection()
        button.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        let attributes: [NSAttributedString.Key: Any] = [.font: nsView.font ?? NSFont.systemFont(ofSize: DaybookType.bodySize)]
        let widest = nsView.itemArray.map { ($0.title as NSString).size(withAttributes: attributes).width }.max() ?? 0
        let current = (nsView.title as NSString).size(withAttributes: attributes).width
        let width = nsView.intrinsicContentSize.width + max(0, widest - current)
        return CGSize(width: min(proposal.width ?? .infinity, width), height: DaybookMetrics.Hit.regular)
    }

    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        button.menu?.cancelTracking()
        coordinator.selection = nil
        coordinator.button = nil
        for item in button.itemArray { item.target = nil; item.action = nil }
    }

    @MainActor final class Coordinator: NSObject {
        weak var button: NSPopUpButton?
        var selection: Binding<Value>?
        var options: [(Value, String)] = []
        var unavailable = ""

        func matches(_ other: [(Value, String)]) -> Bool {
            options.count == other.count && zip(options, other).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        }

        func rebuildMenu() {
            let menu = NSMenu()
            menu.autoenablesItems = false
            for (value, label) in options {
                let item = NSMenuItem(title: label, action: #selector(choose(_:)), keyEquivalent: "")
                item.representedObject = DaybookPickerValue(value)
                item.target = self
                menu.addItem(item)
            }
            button?.menu = menu
        }

        func readSelection() {
            guard let button, let selection, let menu = button.menu else { return }
            // 原生控件可先改变 selectedItem；拒绝写入时立即按 Binding 恢复，不能等待观察通知。
            for item in menu.items where item.representedObject == nil { menu.removeItem(item) }
            let selected = menu.items.first { ($0.representedObject as? DaybookPickerValue<Value>)?.value == selection.wrappedValue }
            if let selected {
                button.select(selected)
            } else {
                let placeholder = NSMenuItem(title: unavailable, action: nil, keyEquivalent: "")
                placeholder.isEnabled = false
                menu.insertItem(placeholder, at: 0)
                button.select(placeholder)
            }
            for item in menu.items { item.state = item === selected ? .on : .off }
            button.setAccessibilityValue(button.title)
            button.toolTip = button.title
        }

        @objc private func choose(_ item: NSMenuItem) {
            guard let button, button.window != nil, button.isEnabled,
                  item.menu === button.menu, let value = item.representedObject as? DaybookPickerValue<Value>,
                  let selection else { return }
            // 原生基线：再次选择当前项也提交一次；不在公共层做去重。
            selection.wrappedValue = value.value
            readSelection()
        }

    }
}

private final class DaybookPickerValue<Value>: NSObject {
    let value: Value
    init(_ value: Value) { self.value = value }
}
