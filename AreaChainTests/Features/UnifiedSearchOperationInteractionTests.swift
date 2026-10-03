import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchOperationInteractionTests {
    @Test func nativeCompletionDraftPickerPreviewAndStaleCandidate() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        (try host.editor).insertText("/set", replacementRange: (try host.editor).selectedRange())
        try await host.settle()
        #expect(fixture.controller.operations?.active == nil)
        let state = try host.state
        let old = try #require(state.completion)
        let command = try #require(old.result.candidates.first { $0.command.id.rawValue == "setting.language" })
        state.suggestions.selectedIndex = try #require(old.result.candidates.firstIndex(of: command))
        try await host.key(48, "\t")
        let draft = try fixture.draft
        #expect(draft.commandID.rawValue == "setting.language")
        let choices = try #require(state.completion)
        let chinese = try #require(choices.result.candidates.first { $0.insertText == "/chinese" })
        state.suggestions.selectedIndex = try #require(choices.result.candidates.firstIndex(of: chinese))
        try await host.key(36, "\r")
        #expect(try fixture.draft.id == draft.id && fixture.draft.arguments.first?.value == .choice("chinese"))
        #expect(!state.accept(command, source: old))
        try host.snapshot("operation-completion-preview")
        let node = try MenuButtonTestSupport.menu("unified.operation.value", in: host.window)
        let menu = try await MenuButtonTestSupport.openAndEscape(node, in: host.window)
        try MenuButtonTestSupport.dispatch("English", in: menu)
        try await host.settle()
        #expect(try fixture.draft.arguments.first?.value == .choice("english"))
        let version = try fixture.draft.version
        try MenuButtonTestSupport.dispatch(L10n.format("language.chinese", locale: Locale(identifier: "en")), in: menu)
        #expect(try fixture.draft.version == version, "旧原生菜单不续接新版本")
        fixture.controller.chooseParameter(.value, source: fixture.controller.buffer)
        try await host.settle()
        let editor = try host.editor
        editor.insertText("简中", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        #expect(try host.state.suggestions.isActive)
        try await host.key(36, "\r")
        #expect(try fixture.draft.arguments.first?.value == .choice("chinese"))
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.operationMessage == "unified.operation.submitBlocked")
        #expect(try fixture.handoff.state().execution == nil)
    }

    @Test func nativeNumberSelectionUndoRedoAndInvalidSpelling() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.limit")
        try fixture.typeParameter(.value, text: "25")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try await host.focusParameter(.value)
        #expect(editor.string == "25")
        #expect(try fixture.draft.arguments.first?.value == .number(25))
        editor.breakUndoCoalescing()
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        editor.insertText("-", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(try editor.string == "-" && fixture.draft.arguments.first?.value == nil)
        #expect(editor.undoManager?.canUndo == true)
        editor.undoManager?.undo()
        try await host.settle()
        #expect(editor.string == "25")
        #expect(try fixture.draft.arguments.first?.value == .number(25))
        editor.undoManager?.redo()
        try await host.settle()
        #expect(try editor.string == "-" && fixture.draft.arguments.first?.value == nil)
        let before = try fixture.draft.version
        try await host.key(36, "\r")
        #expect(try fixture.draft.version == before)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.operationMessage == "unified.operation.submitBlocked")
        try host.snapshot("operation-invalid-number")
        try await host.key(53, "\u{1b}")
        #expect(try fixture.draft.arguments.first?.value == nil)
        #expect(host.window.firstResponder === (try host.editor))
    }

    @Test func nativeShortTextCompositionAndRawContent() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.ignoreApp")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try await host.focusParameter(.bundleID)
        let field = try host.parameterField(.bundleID)
        let state = try #require((field.delegate as? DaybookTextField.Coordinator)?.parent.unifiedSearch)
        let before = try fixture.draft
        editor.setMarkedText("合成", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(try editor.hasMarkedText() && fixture.draft == before)
        #expect(!state.command(#selector(NSResponder.insertNewline(_:)), editor: editor))
        state.submit()
        #expect(fixture.controller.operationMessage != "unified.operation.submitBlocked")
        editor.insertText(" /setting/language #合成 ", replacementRange: editor.markedRange())
        try await host.settle()
        #expect(try fixture.draft.arguments.first?.value == .shortText(" /setting/language #合成 "))
        #expect(fixture.controller.operations?.retained.isEmpty == true)
        try host.snapshot("operation-short-text")
    }

    @Test func nativeBooleanWeekdaysDayAndTime() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("setting.captureSource")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        #expect(try fixture.draft.arguments.isEmpty)
        let node = try MenuButtonTestSupport.menu("unified.operation.value", in: host.window)
        let menu = try await MenuButtonTestSupport.openAndEscape(node, in: host.window)
        try MenuButtonTestSupport.dispatch("Off", in: menu)
        try await host.settle()
        #expect(try fixture.draft.arguments.first?.value == .boolean(false))
        try fixture.startOperation("routine.create")
        try await host.settle()
        try await host.clickResult("unified.operation.discard")
        let weekday = try SettingsButtonTestSupport.elements(host.window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == "Monday"
        }
        let day = try #require(weekday)
        try await SettingsButtonTestSupport.reveal(day, in: host.window)
        try await SettingsButtonTestSupport.click(day, in: host.window)
        #expect(try fixture.draft.arguments.contains { if case .weekdays = $0.value { return true }; return false })
        try await SettingsButtonTestSupport.click(day, in: host.window)
        #expect(try fixture.draft.arguments.first { $0.parameter == .weekdays }?.value == nil)
        for name in ["Monday", "Wednesday"] {
            let node = try #require(SettingsButtonTestSupport.elements(host.window.contentView).first {
                SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == name
            })
            try await SettingsButtonTestSupport.click(node, in: host.window)
        }
        #expect(try fixture.draft.arguments.first { $0.parameter == .weekdays }?.value == .weekdays(0b0001010))
        let time = try TimePickerNativeTestSupport.picker(in: host.window)
        try await SettingsButtonTestSupport.reveal(time, in: host.window)
        let display = DaybookTimePresentation(calendar: try #require(time.calendar))
        let freshRect = time.convert(time.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: freshRect.minX + 10, y: freshRect.midY), in: host.window)
        time.dateValue = try #require(display.date(1439))
        time.sendAction(time.action, to: time.target)
        try await host.settle()
        #expect(try fixture.draft.arguments.first { $0.parameter == .time }?.value == .time(1439))
        let timeRect = time.convert(time.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: timeRect.minX + 10, y: timeRect.midY), in: host.window)
        try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: host.window)
        try await TimePickerNativeTestSupport.key(126, "\u{F700}", in: host.window)
        #expect(try fixture.draft.arguments.first { $0.parameter == .time }?.value == .time(0))
        try host.snapshot("operation-weekdays-time")
        try fixture.startOperation("todo.create")
        try await host.settle()
        try await host.clickResult("unified.operation.discard")
        try await host.clickResult("unified.parameter.date")
        let today = DayKey.today()
        try await DatePickerTestSupport.select(today, in: host.window)
        #expect(try fixture.draft.arguments.first { $0.parameter == .day }?.value == .day(today))
        try host.snapshot("operation-date-expanded")
        let anchor = try host.field.convert(host.field.bounds, to: nil)
        try await host.clickResult("unified.parameter.date")
        #expect(try host.field.convert(host.field.bounds, to: nil) == anchor)
        try host.snapshot("operation-date-multiple")
    }
}
