import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchTrashInteractionTests {
    @Test(arguments: [0, 3]) func singleTrashConfirmationKeyboardCancelAndConfirm(style: Int) async throws {
        let f = try UnifiedSearchTrashFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        let target = f.service.todoTarget
        try await f.command("/tasks/trash", host: host)
        try await f.select([target], host: host)
        let accepted = try await f.prepareAndAccept(host, name: "single-\(style)")
        #expect(accepted.preview.counts == .init(targets: 1, subtasks: 2, attachments: 2))
        let plan = try #require(f.controller.plan)
        let confirmation = try await f.openConfirmation(host, chord: true)
        #expect(confirmation.targets == [target] && confirmation.titles == [f.service.parent.title])
        _ = try host.resultNode("unified.trash.confirmCascade")
        // 默认焦点在取消，确认需要用户主动移过去。
        #expect(try f.focused("unified.trash.cancel", host: host))
        #expect(try !f.focused("unified.trash.confirm", host: host))
        try host.snapshot("tm4-single-confirm-\(style)")
        // 确认期间 ⌘Return 不越过确认。
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.settle()
        #expect(f.service.count("save") == 0 && f.controller.trashConfirmation == confirmation)
        try await host.key(53, "\u{1B}")
        #expect(f.controller.trashConfirmation == nil && f.service.count("save") == 0)
        #expect(f.controller.plan?.items == plan.items && f.controller.currentTrashAcceptance == accepted)
        #expect(f.service.parent.deletedAt == nil)
        let second = try await f.openConfirmation(host, chord: false)
        #expect(second.id != confirmation.id)
        try await host.key(48, "\t")
        #expect(try f.focused("unified.trash.confirm", host: host))
        try await host.clickCompositionControl("unified.trash.confirm")
        let facts = try #require(f.controller.trashUnit?.trash, "回收未执行：\(f.controller.trashFailure ?? "none")")
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.count("ui") == 1)
        let stamp = try #require(f.service.parent.deletedAt)
        #expect(f.service.liveSubtasks.allSatisfy { $0.deletedAt == stamp } && f.service.attachments.allSatisfy { $0.deletedAt == stamp })
        #expect(f.base.routine.deletedAt == nil && f.base.refreshTargets == [target])
        try await host.revealSettingControlInsidePanel("unified.trash.status")
        try host.snapshot("tm4-single-result-\(style)")
    }

    /// 合并批 M-1 B：带备注的对象可以回收；预览与独立确认面板都说明“备注随对象进回收站”。
    @Test(arguments: [0, 3]) func trashWithNotesExplainsNotesInPreviewAndConfirmation(style: Int) async throws {
        let f = try UnifiedSearchTrashFixture()
        defer { f.results.stop() }
        f.service.parent.notes = "合成备注 · synthetic note"
        try f.service.context.save()
        let host = try await f.host(style)
        defer { host.close() }
        try await f.command("/tasks/trash", host: host)
        try await f.select([f.service.todoTarget], host: host)
        let accepted = try await f.prepareAndAccept(host, name: "notes-\(style)")
        #expect(accepted.preview.counts.notes == 1)
        _ = try host.resultNode("unified.trash.notes")
        _ = try await f.openConfirmation(host, chord: true)
        _ = try host.resultNode("unified.trash.confirmNotes")
        #expect(f.service.count("save") == 0)
        try host.snapshot("m1-trash-notes-\(style)")
    }

    @Test(arguments: [1, 2]) func batchTrashCancelButtonKeepsDraftThenConfirms(style: Int) async throws {
        let f = try UnifiedSearchTrashFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        let targets = [f.base.taskTargets[2], f.service.routineTarget]
        let first = f.service.parent.snapshot
        try await f.command("/tasks/batch/trash", host: host)
        try await f.select(targets, host: host)
        let accepted = try await f.prepareAndAccept(host, name: "batch-\(style)")
        // 选择器按结果顺序固定集合；之后一律以冻结顺序为准。
        let frozen = accepted.preview.targets.objects
        #expect(Set(frozen) == Set(targets) && frozen.count == 2)
        let confirmation = try await f.openConfirmation(host, chord: false)
        #expect(confirmation.targets == frozen && confirmation.titles.count == 2)
        #expect(try f.focused("unified.trash.cancel", host: host))
        try host.snapshot("tm4-batch-confirm-\(style)")
        try await host.clickCompositionControl("unified.trash.cancel")
        #expect(f.controller.trashConfirmation == nil && f.controller.currentTrashAcceptance == accepted)
        #expect(f.controller.plan?.items.first?.draft.targets.objects == frozen && f.service.count("save") == 0)
        _ = try await f.openConfirmation(host, chord: true)
        try await host.clickCompositionControl("unified.trash.confirm")
        let facts = try #require(f.controller.trashUnit?.trash)
        #expect(facts.state == .saved && f.service.count("save") == 1)
        #expect(f.base.todos[2].deletedAt != nil && f.base.routine.deletedAt != nil)
        // 同 UUID 的 todos[0] 未被选中，不得被批量回收波及。
        #expect(f.service.parent.snapshot == first)
        try await host.revealSettingControlInsidePanel("unified.trash.status")
        try host.snapshot("tm4-batch-result-\(style)")
    }

    @Test func targetChangedAfterConfirmationRequiresRepreview() async throws {
        let f = try UnifiedSearchTrashFixture()
        defer { f.results.stop() }
        let host = try await f.host(2)
        defer { host.close() }
        try await f.command("/tasks/trash", host: host)
        try await f.select([f.service.todoTarget], host: host)
        _ = try await f.prepareAndAccept(host, name: "changed")
        _ = try await f.openConfirmation(host, chord: false)
        f.service.parent.title = "确认后外部改名 · Renamed"
        try f.service.context.save()
        try await host.clickCompositionControl("unified.trash.confirm")
        #expect(f.controller.trashConfirmation == nil && f.controller.trashPreview == nil && f.controller.trashAcceptance == nil)
        #expect(f.controller.trashFailure == "unified.trash.targetsChanged" && f.controller.settingExecution == nil)
        #expect(f.service.count("save") == 0 && f.service.parent.deletedAt == nil)
        #expect(f.controller.plan?.items.count == 1)
        try await host.revealSettingControlInsidePanel("unified.trash.issue")
        try host.snapshot("tm4-changed-rejected")
    }

    @Test(arguments: [0, 1, 2, 3]) func copySectionsSucceedAndWriteFailureIsHonest(style: Int) async throws {
        let f = try UnifiedSearchTrashFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        let todo = f.base.todos[1]
        let section = TaskCopySection.allCases[style % 3]
        try await f.command("/tasks/copy", host: host)
        try await f.select([.init(type: .todo, id: todo.id)], host: host)
        let picker = try await host.compositionPicker("unified.parameter.choice.section")
        for _ in 0...(style % 3) { try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window) }
        #expect(f.controller.editingDraft?.arguments.first { $0.parameter == .section }?.value == .choice(section.rawValue))
        try await host.clickCompositionControl("unified.copy.prepare")
        let preview = try #require(f.controller.currentTaskCopyPreview, "复制准备失败：\(f.controller.taskCopyFailure ?? "none")")
        let expected = TaskCopyContent.text(section, title: todo.title, notes: TaskCopyContent.notes(todo.notes))
        #expect(preview.text == expected && f.writer.writes.isEmpty)
        try host.snapshot("tm4-copy-preview-\(style)")
        if style == 3 {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.copy.submit") }
        #expect(f.writer.writes == [expected].compactMap { $0 })
        try await host.revealSettingControlInsidePanel("unified.copy.status")
        try host.snapshot("tm4-copy-success-\(style)")
        f.writer.fails = true
        try await host.clickCompositionControl("unified.copy.submit")
        #expect(f.writer.writes.count == 1 && f.controller.taskCopyFailure == "unified.copy.writeFailed")
        #expect(!f.has("unified.copy.status", host: host))
        try await host.revealSettingControlInsidePanel("unified.copy.issue")
        try host.snapshot("tm4-copy-failure-\(style)")
        #expect(f.service.count("save") == 0 && f.controller.settingExecution == nil && f.controller.plan?.items.isEmpty == true)
    }

    @Test func taskRowCopyUsesSharedRuleAndReportsWriteFailure() async throws {
        let writer = FakeClipboardWriter()
        let notes = "  行内备注\n第二行 e\u{301}  "
        let state = TaskRowState(identity: TaskRowIdentityState(title: "  行复制 · Row copy  "),
                                 content: TaskRowContentState(notes: notes),
                                 interaction: TaskRowInteractionState(selection: TaskRowSelectionState(isSelected: true)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 60), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: TaskRow(state: state, dispatch: { _ in })
            .frame(width: 380, height: 60).environment(\.locale, Locale(identifier: "zh-Hans"))
            .environment(\.clipboardTextWriter, writer))
        let attribute = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previous = NSApp.accessibilityAttributeValue(attribute)
        NSApp.accessibilitySetValue(true, forAttribute: attribute)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer {
            SystemPageHost.release(window)
            NSApp.accessibilitySetValue(previous ?? false, forAttribute: attribute)
        }
        try await SystemPageHost.settle(window)
        let labels = ["en", "zh-Hans"].flatMap { id in
            ["diary.quick.copy", "diary.copied"].map { L10n.string($0, locale: Locale(identifier: id)) }
        }
        func copyButton() throws -> NSObject {
            let nodes = SettingsButtonTestSupport.elements(window.contentView)
            return try #require(nodes.first { labels.contains(SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String ?? "") },
                "labels=\(nodes.compactMap { SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String })")
        }
        func copied() throws -> Bool {
            let label = SettingsButtonTestSupport.value(try copyButton(), "accessibilityLabel") as? String
            return ["en", "zh-Hans"].map { L10n.string("diary.copied", locale: Locale(identifier: $0)) }.contains(label ?? "")
        }
        writer.fails = true
        try await SettingsButtonTestSupport.click(copyButton(), in: window)
        try await SystemPageHost.settle(window)
        #expect(writer.writes.isEmpty)
        #expect(try !copied())
        writer.fails = false
        try await SettingsButtonTestSupport.click(copyButton(), in: window)
        try await SystemPageHost.settle(window)
        #expect(writer.writes == ["  行复制 · Row copy  \n行内备注\n第二行 e\u{301}"])
        #expect(try copied())
    }

    /// 共享气泡：报告失败不显示已复制；未设置结果回调的旧宿主（手记、甘特等）沿原路径仍显示。
    @Test(arguments: ["title-fail", "title-ok", "note-fail", "note-ok", "legacy"])
    func rowBubblesShowCopiedOnlyWhenWriteSucceeds(mode: String) async throws {
        var calls = 0
        let succeeds = !mode.hasSuffix("fail")
        let bubble: AnyView
        if mode.hasPrefix("note") {
            bubble = AnyView(RowNoteBubble(note: "合成备注 · Synthetic note", growsUpward: false, bubbleShiftX: 0, onCopy: {})
                .reportingCopyResult { calls += 1; return succeeds })
        } else if mode == "legacy" {
            bubble = AnyView(RowTitleBubble(title: "合成标题 · Synthetic title", growsUpward: false, onCopy: { calls += 1 }))
        } else {
            bubble = AnyView(RowTitleBubble(title: "合成标题 · Synthetic title", growsUpward: false, onCopy: {})
                .reportingCopyResult { calls += 1; return succeeds })
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 120), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: bubble.frame(width: 300, height: 120)
            .environment(\.locale, Locale(identifier: "zh-Hans")))
        let attribute = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previous = NSApp.accessibilityAttributeValue(attribute)
        NSApp.accessibilitySetValue(true, forAttribute: attribute)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer {
            SystemPageHost.release(window)
            NSApp.accessibilitySetValue(previous ?? false, forAttribute: attribute)
        }
        try await SystemPageHost.settle(window)
        let copied = L10n.string("diary.copied", locale: Locale(identifier: "zh-Hans"))
        func showsCopied() -> Bool {
            SettingsButtonTestSupport.elements(window.contentView).contains { node in
                ["accessibilityLabel", "accessibilityValue", "accessibilityTitle"].contains { key in
                    SettingsButtonTestSupport.value(node, key) as? String == copied
                }
            }
        }
        #expect(!showsCopied())
        let center = NSPoint(x: 150, y: 60)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: center, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
        #expect(calls == 1)
        #expect(showsCopied() == succeeds)
    }
}
