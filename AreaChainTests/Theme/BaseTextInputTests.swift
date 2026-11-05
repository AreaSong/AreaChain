import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow))
@MainActor
struct BaseTextInputTests {
    @Test func threeLineModesFollowShellMetricsAndSanitizePaste() async throws {
        var singleText = ""
        var searchText = ""
        var multiText = "第一行\n第二行"
        var secureText = "secret"
        var focused = false
        let focusBinding = Binding(get: { focused }, set: { focused = $0 })

        let content = VStack(alignment: .leading, spacing: 10) {
            BaseTextInput.composer(
                text: Binding(get: { singleText }, set: { singleText = $0 }),
                placeholder: "添加待办",
                focus: focusBinding
            )
            .background(BaseInputMarker(name: "composer"))

            BaseTextInput.search(
                text: Binding(get: { searchText }, set: { searchText = $0 }),
                placeholder: "搜索或输入命令",
                focus: focusBinding
            )
            .background(BaseInputMarker(name: "search"))

            BaseTextInput.editor(
                text: Binding(get: { multiText }, set: { multiText = $0 }),
                placeholder: "记录手记",
                focus: focusBinding,
                minHeight: 84,
                maxHeight: 160
            )
            .background(BaseInputMarker(name: "editor"))

            BaseTextInput.secure(
                text: Binding(get: { secureText }, set: { secureText = $0 }),
                placeholder: "输入主密码",
                focus: focusBinding
            )
            .background(BaseInputMarker(name: "secure"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 400, height: 320))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)

        let composerView = try #require(marker("composer", in: host))
        #expect(abs(composerView.bounds.height - DaybookMetrics.inputHeight) < 1.5)

        let searchView = try #require(marker("search", in: host))
        #expect(abs(searchView.bounds.height - DaybookMetrics.controlHeight) < 1.5)

        let editorView = try #require(marker("editor", in: host))
        #expect(editorView.bounds.height >= 83)
        #expect(editorView.bounds.height <= 161)

        let secureView = try #require(marker("secure", in: host))
        #expect(abs(secureView.bounds.height - DaybookMetrics.controlHeight) < 1.5)

        let merged = BaseTextInput<EmptyView, EmptyView>.sanitizeSingleLinePaste("买牛奶\n#生活\r\n!p1")
        #expect(!merged.contains("\n"))
        #expect(!merged.contains("\r"))
        #expect(merged == "买牛奶 #生活  !p1")
    }

    @Test func prefixAndSuffixSlotsMountAndSwitchPrivacyShield() async throws {
        var text = "#私密 账号记录"
        var focused = false
        var actionFired = false
        let focusBinding = Binding(get: { focused }, set: { focused = $0 })

        let view = BaseTextInput.composer(
            text: Binding(get: { text }, set: { text = $0 }),
            placeholder: "输入内容",
            focus: focusBinding,
            prefix: {
                BaseInputPrivacyPrefix(defaultSystemImage: "magnifyingglass", isPrivate: text.contains("#私密"))
                    .background(BaseInputMarker(name: "slot.prefix"))
            },
            suffix: {
                DaybookActionButton(
                    actionID: "composer.openWindow",
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    tooltip: "打开独立小窗",
                    role: .icon,
                    size: .compact,
                    action: { actionFired = true }
                )
                .background(BaseInputMarker(name: "slot.suffix"))
            }
        )

        let host = NSHostingView(rootView: view)
        let window = makeWindow(host, size: NSSize(width: 360, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)

        let prefixSlot = try #require(marker("slot.prefix", in: host))
        let suffixSlot = try #require(marker("slot.suffix", in: host))
        #expect(prefixSlot.bounds.width > 0)
        #expect(suffixSlot.bounds.width > 0)
        let prefixInHost = prefixSlot.convert(prefixSlot.bounds, to: host)
        let suffixInHost = suffixSlot.convert(suffixSlot.bounds, to: host)
        #expect(prefixInHost.minX < suffixInHost.minX)

        let button = DaybookActionButton(
            actionID: "composer.openWindow",
            systemImage: "arrow.up.left.and.arrow.down.right",
            tooltip: "打开独立小窗",
            role: .icon,
            size: .compact,
            action: { actionFired = true }
        )
        button.trigger()
        #expect(actionFired == true)
    }

    @Test func markedTextCompositionBlocksPrematureSubmissionAndKeyboardCallbacks() {
        var text = ""
        var focused = true
        var submitCount = 0
        var commandReturnCount = 0
        var tabCount = 0
        var escapeCount = 0
        var arrows: [BaseInputVerticalDirection] = []

        let singleLine = BaseSingleLineTextField(
            text: Binding(get: { text }, set: { text = $0 }),
            placeholder: "测试输入法保护",
            focus: Binding(get: { focused }, set: { focused = $0 }),
            syntaxPlugin: .taskSyntax,
            fontSize: DaybookType.bodySize,
            fontWeight: .regular,
            newlinePolicy: .capture,
            commandChord: nil,
            autocomplete: nil,
            availableTags: ["工作"],
            onSubmit: { submitCount += 1 },
            onCommandReturn: { commandReturnCount += 1 },
            onTab: { tabCount += 1 },
            onEscape: { escapeCount += 1 },
            onVerticalArrow: { arrows.append($0) }
        )

        let coordinator = singleLine.makeCoordinator()
        let field = DaybookAppKitTextField(string: "")
        let cell = DaybookTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isSelectable = true
        field.cell = cell
        field.isEditable = true
        field.isSelectable = true
        field.delegate = coordinator

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(field)
        window.orderBack(nil)
        _ = window.makeFirstResponder(field)
        defer { window.contentView = nil; window.orderOut(nil) }

        let editor = (field.currentEditor() as? NSTextView) ?? DaybookFieldEditor(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        coordinator.beginEditing(field, editor: editor)

        // 模拟中文输入法正在拼音组词（markedText 激活）
        editor.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: 0, length: 0))
        #expect(editor.hasMarkedText() == true)

        // 组词期间按回车、Tab、Esc、上下方向键及 ⌘↩ 均不得误触发业务回调
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))) == false)
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertTab(_:))) == false)
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))) == false)
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))) == false)
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))) == false)
        coordinator.triggerCommandReturn(in: field)

        #expect(submitCount == 0)
        #expect(commandReturnCount == 0)
        #expect(tabCount == 0)
        #expect(escapeCount == 0)
        #expect(arrows.isEmpty)

        // 组词期间外部文本同步不得冲掉正在输入的组合串
        BaseSingleLineTextField.synchronizeText("外部覆盖", in: field, syntaxPlugin: .taskSyntax, font: singleLine.nativeFont)
        #expect(editor.hasMarkedText() == true)

        // 完成选词上屏后，各按键回调恢复正常响应
        editor.insertText("你好 #工作", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        #expect(editor.hasMarkedText() == false)

        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertTab(_:))) == true)
        #expect(tabCount == 1)

        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))) == true)
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))) == true)
        #expect(arrows == [.up, .down])

        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))) == true)
        #expect(submitCount == 1)
        #expect(text == "你好 #工作")

        coordinator.triggerCommandReturn(in: field)
        #expect(commandReturnCount == 1)

        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))) == true)
        #expect(escapeCount == 1)
    }

    @Test func syntaxPluginsHighlightExpectedTokenCategories() {
        let font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        let sample = "/done 买牛奶 #生活 !p1 tag:生活"

        let plain = BaseInputSyntaxHighlighter.attributedString(for: sample, plugin: .none, font: font)
        let taskColored = BaseInputSyntaxHighlighter.attributedString(for: sample, plugin: .taskSyntax, font: font)
        let tagOnlyColored = BaseInputSyntaxHighlighter.attributedString(for: sample, plugin: .tagOnly, font: font)
        let commandColored = BaseInputSyntaxHighlighter.attributedString(for: sample, plugin: .commandSearch, font: font)

        let nsSample = sample as NSString
        let cmdRange = nsSample.range(of: "/done")
        let tagRange = nsSample.range(of: "#生活")
        let p1Range = nsSample.range(of: "!p1")

        let defaultColor = NSColor(DaybookPalette.text.primary)
        #expect((plain.attribute(.foregroundColor, at: tagRange.location, effectiveRange: nil) as? NSColor) == defaultColor)
        #expect((taskColored.attribute(.foregroundColor, at: tagRange.location, effectiveRange: nil) as? NSColor) == DaybookPalette.Syntax.tagNS)
        #expect((taskColored.attribute(.foregroundColor, at: p1Range.location, effectiveRange: nil) as? NSColor) == DaybookPalette.Syntax.p1NS)

        // tagOnly 只着色 #标签，不着色 !p1
        #expect((tagOnlyColored.attribute(.foregroundColor, at: tagRange.location, effectiveRange: nil) as? NSColor) == DaybookPalette.Syntax.tagNS)
        #expect((tagOnlyColored.attribute(.foregroundColor, at: p1Range.location, effectiveRange: nil) as? NSColor) == defaultColor)

        // commandSearch 同时着色 /命令 与语法标记
        #expect((commandColored.attribute(.foregroundColor, at: cmdRange.location, effectiveRange: nil) as? NSColor) == NSColor(DaybookPalette.accent.base))
        #expect((commandColored.attribute(.foregroundColor, at: tagRange.location, effectiveRange: nil) as? NSColor) == DaybookPalette.Syntax.tagNS)
    }

    @Test func daybookActionButtonSyncsDisabledStateTooltipAndRegistryDispatch() {
        let dispatcher = DaybookActionDispatcher()
        var registeredRunCount = 0
        dispatcher.register(actionID: "task.complete") {
            registeredRunCount += 1
        }
        dispatcher.availabilityResolver = { id in
            if id == "task.delete.locked" {
                return (false, "请先解锁隐私保护")
            }
            return (true, nil)
        }

        let enabledButton = DaybookActionButton(
            actionID: "task.complete",
            title: "完成",
            systemImage: "checkmark.circle",
            role: .prominent,
            size: .compact,
            dispatcher: dispatcher
        )
        #expect(enabledButton.effectiveEnabled == true)
        enabledButton.trigger()
        #expect(registeredRunCount == 1)
        #expect(dispatcher.lastTriggeredActionID == "task.complete")

        let lockedButton = DaybookActionButton(
            actionID: "task.delete.locked",
            title: "删除",
            role: .destructive,
            size: .regular,
            dispatcher: dispatcher
        )
        #expect(lockedButton.effectiveEnabled == false)
        #expect(lockedButton.effectiveTooltip == "请先解锁隐私保护")
        lockedButton.trigger()
        #expect(dispatcher.lastTriggeredActionID == "task.complete")
    }

    private func makeWindow(_ view: NSView, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.setContentSize(size)
        window.orderBack(nil)
        return window
    }

    private func settle(_ view: NSView) async throws {
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        view.layoutSubtreeIfNeeded()
    }

    private func marker(_ name: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == name { return view }
        return view.subviews.lazy.compactMap { marker(name, in: $0) }.first
    }
}

private struct BaseInputMarker: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
