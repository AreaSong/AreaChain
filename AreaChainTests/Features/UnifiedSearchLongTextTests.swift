import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchLongTextTests {
    @Test func explicitAssemblyKeepsBodyOutOfQueryAndPreservesOperations() async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        try f.startOperation("todo.notes")
        let parameter = try f.parameter(.notes).0
        #expect(!f.controller.supportsLongText(parameter))
        f.controller.assembleLongText(vault: f.vault)
        #expect(f.controller.supportsLongText(parameter))
        f.controller.beginLongText(.notes, source: f.controller.buffer)
        let editing = try #require(f.controller.longTextEditing)
        let editor = CommandProtectedTextView(session: editing.content)
        defer { editor.end() }
        try editing.attach(editor)
        editor.onRevision = { f.controller.longTextAdvanced(editing) }
        editor.insertText("正文 / # ! @\n第二行", replacementRange: NSRange(location: 0, length: 0))
        #expect(try f.draft.arguments.first?.value == .longText("正文 / # ! @\n第二行"))
        #expect(!f.controller.buffer.text.contains("正文"))
        #expect(f.controller.parameterText.isEmpty)
        let before = try f.handoff.owned()
        f.controller.requestOperationSubmit(f.controller.buffer)
        #expect(try f.handoff.owned() == before)
        try editor.changeOperation(.append)
        #expect(editor.access == nil)
        try editor.begin(using: editing.content.explicitlyEditOrdinary(f.draft.stamp, expecting: f.handoff.owned().lease))
        editor.insertText("追加", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        #expect(try f.draft.arguments.first?.operation == .append)
        #expect(try f.draft.arguments.first?.value == .longText("追加"))
        try editor.changeOperation(.clear)
        #expect(!editor.isEditable)
        #expect(try f.draft.arguments.first?.operation == .clear && f.draft.arguments.first?.value == nil)
        #expect(try f.handoff.state().execution == nil)
    }

    @Test func twoContentServicesCannotAttachOwnersForSameField() throws {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        let other = CommandDraftContentSession(coordinator: f.host.coordinator, vault: f.vault)
        let first = CommandProtectedTextView(session: f.service)
        let second = CommandProtectedTextView(session: other)
        defer { first.end(); second.end() }
        let stamp = try f.draft().stamp
        let lease = try f.host.owned().lease
        try first.begin(using: f.service.explicitlyEditOrdinary(stamp, expecting: lease))
        #expect(throws: (any Error).self) { try second.begin(using: other.explicitlyEditOrdinary(stamp, expecting: lease)) }
        first.insertText("唯一", replacementRange: NSRange(location: 0, length: first.string.utf16.count))
        #expect(first.string == "唯一")
    }

    @Test func bodyPlanOwnerSurvivesCollapseAndRejectsOldEvents() async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: f.vault)
        try f.startOperation("diary.body")
        #expect(f.controller.enqueue(try f.draft.stamp, source: f.controller.buffer))
        let item = try #require(f.controller.plan?.items.first)
        f.controller.beginPlanEditing(item.stamp, source: f.controller.buffer)
        f.controller.beginLongText(.body, source: f.controller.buffer)
        let editing = try #require(f.controller.longTextEditing)
        let editor = CommandProtectedTextView(session: editing.content, parameter: .body)
        try editing.attach(editor)
        editor.onRevision = { f.controller.longTextAdvanced(editing) }
        editor.insertText("计划长文", replacementRange: NSRange(location: 0, length: 0))
        let old = try #require(editor.access)
        f.controller.endLongText()
        #expect(editor.string.isEmpty && editor.access == nil)
        f.controller.beginLongText(.body, source: f.controller.buffer)
        let resumed = try #require(f.controller.longTextEditing)
        let current = CommandProtectedTextView(session: resumed.content, parameter: .body)
        defer { current.end() }
        try resumed.attach(current)
        #expect(current.string == "计划长文")
        editor.synchronize("旧正文", selection: NSRange(location: 0, length: 0), expecting: old)
        editor.end()
        #expect(current.string == "计划长文" && current.access != nil)
        #expect(f.controller.operations?.active == nil)
        #expect(f.controller.plan?.items.first?.draft.arguments.first?.value == .longText("计划长文"))
        #expect(throws: (any Error).self) { try f.handoff.seal() }
    }

    @Test(.serialized, arguments: [false, true])
    func nativeParameterLayoutsAndCollapse(dark: Bool) async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: f.vault)
        try f.startOperation("todo.notes")
        let host = UnifiedSearchTestHost(layout: dark ? .compact : .standard, width: dark ? 480 : 740,
            locale: dark ? "zh-Hans" : "en", dark: dark, results: f.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.longText.open.notes")
        try await host.settle()
        let editor = try #require(f.controller.longTextEditing?.editor)
        try await SettingsButtonTestSupport.reveal(editor, in: host.window)
        try #require(host.window.makeFirstResponder(editor))
        editor.insertText(String(repeating: "合成正文 multilingual 🙂 / # ! @\n", count: 30),
                          replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        #expect(editor.window === host.window && editor.enclosingScrollView != nil)
        #expect(editor.bounds.width > 100 && editor.enclosingScrollView!.bounds.height > 100)
        #expect(editor.string.contains("合成正文"))
        #expect(editor.frame.height > editor.enclosingScrollView!.contentSize.height)
        let originalLength = editor.string.utf16.count
        editor.insertText("追加", replacementRange: .init(location: editor.string.utf16.count, length: 0))
        try await host.key(6, "z", flags: .command)
        #expect(editor.string.utf16.count == originalLength)
        try await host.key(6, "z", flags: [.command, .shift])
        #expect(editor.string.utf16.count == originalLength + 2)
        try host.snapshot(dark ? "CM1-zh-dark-compact" : "CM1-en-light-standard")
        let count = editor.string.utf16.count
        let source = f.controller.buffer
        f.controller.operationExpanded = false
        f.controller.endLongText()
        try await host.settle()
        #expect(editor.string.isEmpty)
        #expect(f.controller.buffer == source)
        if case .longText(let body) = try f.draft.arguments.first?.value { #expect(body.utf16.count == count) }
        else { Issue.record("原参数未保留正文") }
    }

    @Test(arguments: [false, true])
    func overLimitInputPasteReplacementAndCompositionKeepAcceptedText(protected: Bool) async throws {
        let f = try LongTextLimitFixture(protected: protected)
        defer { f.results.stop() }
        let limit = CommandLongTextLimit.maxUTF8Bytes
        let base = String(repeating: "中", count: limit / 3 - 1) + "a"
        let controller = try await f.open(body: base)
        let editing = try #require(controller.longTextEditing)
        let editor = CommandProtectedTextView(session: editing.content)
        defer { editor.end() }
        try editing.attach(editor)
        editor.onRevision = { controller.longTextAdvanced(editing) }
        let atLimit = base + "中"
        editor.insertText("中", replacementRange: .init(location: NSNotFound, length: 0))
        #expect(editor.string == atLimit && editor.issue == nil)
        let checkpoints = editor.checkpointCount
        let selection = editor.selectedRange()
        editor.insertText("a", replacementRange: .init(location: NSNotFound, length: 0))
        #expect(editor.string == atLimit && editor.selectedRange() == selection && editor.checkpointCount == checkpoints)
        #expect(editor.issue == .tooLong && editing.message == "unified.longText.tooLong")
        let board = NSPasteboard(name: .init("AreaChain.CM3.synthetic." + UUID().uuidString))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setString("合成粘贴", forType: .string)
        #expect(!editor.readSelection(from: board, type: .string))
        #expect(editor.string == atLimit && editor.issue == .tooLong)
        editor.setSelectedRange(.init(location: 0, length: 1))
        editor.insertText("🙂", replacementRange: editor.selectedRange())
        #expect(editor.string == atLimit && editor.selectedRange() == .init(location: 0, length: 1) && editor.issue == .tooLong)
        // 被拒修改没有进入撤销栈：撤销回到上一次接受前，重做恢复满额正文。
        editor.undoManager?.undo()
        #expect(editor.string == base)
        editor.undoManager?.redo()
        #expect(editor.string == atLimit)
        editor.undoManager?.undo()
        editor.setSelectedRange(.init(location: base.utf16.count, length: 0))
        editor.setMarkedText("zhongwen", selectedRange: .init(location: 8, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        #expect(editor.hasMarkedText() && editor.issue == nil)
        editor.insertText("中文", replacementRange: editor.markedRange())
        #expect(!editor.hasMarkedText() && editor.string == base && editor.issue == .tooLong)
        #expect(editor.selectedRange() == .init(location: base.utf16.count, length: 0))
        #expect(editing.message == "unified.longText.tooLong")
        // 组合输入未被禁用：上限内的下一次组词照常确认。
        editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        editor.insertText("中", replacementRange: editor.markedRange())
        #expect(editor.string == atLimit && editor.issue == nil && editing.message == "unified.longText.draftOnly")
        if !protected { #expect(try f.results.draft.arguments.first?.value == .longText(atLimit)) }
        for (locale, phrase) in [("en", "limit"), ("zh-Hans", "上限")] {
            for key in Array(UnifiedSearchLongTextOversize.limitedKeys) + ["unified.operation.tooLong"] {
                let text = L10n.format(key, locale: Locale(identifier: locale), limit / 1_024)
                #expect(text != key && text.contains("64 KB") && text.contains(phrase))
            }
            for key in ["unified.longText.clearOversized", "unified.longText.openOwner"] {
                #expect(L10n.format(key, locale: Locale(identifier: locale)) != key)
            }
            // 习惯引导用长文专用措辞，不再借用图片拥有者文案。
            let routine = L10n.format("unified.longText.ownerNeedsDay", locale: Locale(identifier: locale))
            let image = L10n.format("unified.content.ownerNeedsDay", locale: Locale(identifier: locale))
            #expect(routine != "unified.longText.ownerNeedsDay" && routine != image)
            #expect(!routine.localizedCaseInsensitiveContains(locale == "en" ? "image" : "图片"))
        }
    }

    @Test(arguments: [false, true])
    func oversizedOldDraftOpensNoEditorAndOffersOnlyApplicableGuidance(protected: Bool) async throws {
        let f = try LongTextLimitFixture(protected: protected)
        defer { f.results.stop() }
        let big = String(repeating: "🙂", count: CommandLongTextLimit.maxUTF8Bytes / 4 + 1)
        let todo = CommandObjectReference(type: .todo, id: UUID())
        let controller = try await f.open(body: big, target: todo)
        #expect(controller.longTextEditing == nil)
        #expect(try controller.longTextOversized == .init(draftID: f.results.draft.id, parameter: .notes))
        #expect(controller.longTextMessage == "unified.longText.tooLongDraft")
        #expect(try controller.longTextOwner(f.results.draft) == todo)
        if protected {
            #expect(try f.restoredNotes() == .longText(big))
        } else {
            #expect(try f.results.draft.arguments.first?.value == .longText(big))
            let issue = UnifiedSearchOperationCopy.issue(.tooLong(.notes), locale: Locale(identifier: "zh-Hans"))
            #expect(try f.results.draft.check().argumentIssues.contains(.tooLong(.notes)) && issue.contains("64 KB"))
        }
        // 引导沿原导航核验：未装配不跳转；习惯给出长文专用的需执行日提示；任务仍经原解析拒绝不存在的对象；手记缺内容路由不跳转。
        controller.openLongTextOwner(todo, source: controller.buffer)
        #expect(controller.longTextMessage == "unified.navigation.unassembled")
        let data = try TaskContentQueryFixture()
        controller.navigationRouter = WorkspaceSearchRouter(navigation: WorkspaceNavigation(boardSelection: BoardSelection()),
            objects: WorkspaceObjectNavigation(context: data.context, calendar: .current, allows: { _ in true }))
        controller.openLongTextOwner(.init(type: .routine, id: UUID()), source: controller.buffer)
        #expect(controller.longTextMessage == "unified.longText.ownerNeedsDay")
        controller.openLongTextOwner(todo, source: controller.buffer)
        #expect(controller.longTextMessage == "unified.navigation.invalidTarget" && controller.returnSearch == nil)
        controller.openLongTextOwner(.init(type: .diary, id: UUID()), source: controller.buffer)
        #expect(controller.longTextMessage == "unified.navigation.unassembled" && controller.returnSearch == nil)
        controller.navigationRouter = nil
        controller.clearOversizedLongText(.notes, source: controller.buffer)
        #expect(controller.longTextOversized == nil && controller.longTextEditing == nil)
        let cleared: [CommandArgument] = [.init(parameter: .notes, operation: .clear, value: nil)]
        if protected { #expect(try f.restoredNotes() == nil && f.restoredArguments() == cleared) }
        else { #expect(try f.results.draft.arguments == cleared) }
        controller.beginLongText(.notes, source: controller.buffer)
        #expect(controller.longTextEditing != nil && controller.longTextOversized == nil)
        controller.endLongText()
    }

    @Test(.serialized, arguments: [false, true])
    func oversizedGuidanceRendersInBothLanguagesAndOnlyForTargets(dark: Bool) async throws {
        let data = try TaskContentQueryFixture()
        let todo = data.todo("合成任务")
        try data.context.save()
        let router = WorkspaceSearchRouter(navigation: WorkspaceNavigation(boardSelection: BoardSelection()),
            objects: WorkspaceObjectNavigation(context: data.context, calendar: .current, allows: { _ in true }))
        let big = String(repeating: "中a🙂", count: CommandLongTextLimit.maxUTF8Bytes / 8 + 1)
        let cases: [(String, CommandParameterID, CommandObjectReference?, Bool)] = [
            ("todo.notes", .notes, .init(type: .todo, id: todo.id), true),
            ("routine.notes", .notes, .init(type: .routine, id: UUID()), false),
            ("diary.create", .body, nil, false)
        ]
        for (command, parameter, target, guided) in cases {
            let f = try LongTextLimitFixture(protected: false)
            defer { f.results.stop() }
            f.results.controller.navigationRouter = router
            _ = try await f.open(body: big, command: command, parameter: parameter, target: target, begin: false)
            let host = UnifiedSearchTestHost(layout: dark ? .compact : .standard, width: dark ? 480 : 740,
                locale: dark ? "zh-Hans" : "en", dark: dark, results: f.results.controller, operations: true)
            defer { host.close() }
            try await host.start()
            try await host.clickResult("unified.longText.open." + parameter.rawValue)
            try await host.settle()
            #expect(f.results.controller.longTextEditing == nil && f.results.controller.longTextOversized != nil)
            let nodes = SettingsButtonTestSupport.elements(host.window.contentView)
            func has(_ id: String) -> Bool { nodes.contains { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id } }
            #expect(has("unified.longText.message"))
            #expect(!nodes.contains { $0 is CommandProtectedTextView })
            #expect(has("unified.longText.openOwner." + parameter.rawValue) == guided)
            #expect(has("unified.longText.clearOversized." + parameter.rawValue) == (command != "diary.create"))
            #expect(try f.results.controller.longTextOwner(f.results.draft)?.type == target?.type)
            #expect(has("unified.longText.ownerNeedsDay") == (target?.type == .routine))
            let last = ["unified.longText.ownerNeedsDay", "unified.longText.openOwner." + parameter.rawValue,
                        "unified.longText.clearOversized." + parameter.rawValue, "unified.longText.message"].first(where: has)!
            try await SettingsButtonTestSupport.reveal(try host.resultNode(last), in: host.window)
            try await host.settle()
            try host.snapshot("CM3-oversized-\(command)-\(dark ? "zh-dark" : "en-light")")
        }
    }

    @Test func overLimitOwnerButtonUsesExistingObjectNavigation() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let controller = fixture.controller!
        controller.assembleLongText(vault: fixture.vault)
        try #require(controller.beginOperation(.init(rawValue: "todo.notes"), source: controller.buffer) != nil)
        let todo = CommandObjectReference(type: .todo, id: fixture.todo.id)
        let stamp = try #require(controller.operations?.active?.stamp)
        try fixture.handoff.send(.operation(.selectTargets(stamp, .init(.single, objects: [todo]))))
        let edited = try #require(controller.operations?.active?.stamp)
        try fixture.handoff.send(.operation(.edit(edited, .init(parameter: .notes, operation: .replace,
            value: .longText(String(repeating: "中", count: CommandLongTextLimit.maxUTF8Bytes / 3 + 1))))))
        _ = controller.publishOperation(text: controller.buffer.text)
        controller.beginLongText(.notes, source: controller.buffer)
        try #require(controller.longTextOversized != nil && controller.longTextEditing == nil)
        let saves = fixture.saves
        controller.openLongTextOwner(todo, source: controller.buffer)
        await controller.navigationTask?.value
        try await fixture.settle()
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.navigation.selectedTaskID == fixture.todo.id)
        #expect(fixture.saves == saves && controller.returnSearch != nil)
    }
}

/// 只用合成内存草稿；受保护时复用 ProtectedDraftFixture 的合成 vault，不触碰真实钥匙串或用户库。
@MainActor private final class LongTextLimitFixture {
    let synthetic: ProtectedDraftFixture
    let results: UnifiedSearchResultsFixture
    let protected: Bool

    init(protected: Bool) throws {
        self.protected = protected
        synthetic = try ProtectedDraftFixture(configured: protected)
        results = try UnifiedSearchResultsFixture(testVault: synthetic.vault)
    }

    func open(body: String, command: String = "todo.notes", parameter: CommandParameterID = .notes,
              target: CommandObjectReference? = nil, begin: Bool = true) async throws -> UnifiedSearchController {
        _ = try await results.publish()
        let controller = results.controller!
        controller.assembleLongText(vault: synthetic.vault)
        try results.startOperation(command)
        if let target {
            try results.handoff.send(.operation(.selectTargets(results.draft.stamp, .init(.single, objects: [target]))))
        }
        let operation = try #require(CommandCatalog.standard.command(id: .init(rawValue: command))?
            .parameters.first { $0.id == parameter }).defaultOperation
        try results.handoff.send(.operation(.edit(results.draft.stamp, .init(parameter: parameter, operation: operation, value: .longText(body)))))
        _ = controller.publishOperation(text: controller.buffer.text)
        if protected {
            controller.protectLongText(source: controller.buffer)
            try #require(controller.editingDraft?.protectedReference != nil)
        }
        if begin { controller.beginLongText(parameter, source: controller.buffer) }
        return controller
    }

    func restoredArguments() throws -> [CommandArgument] {
        let content = try #require(results.controller.longTextContent)
        let access = try content.explicitlyRestore(results.draft.stamp, expecting: results.controller.buffer.lease)
        defer { content.revokeAccess() }
        var arguments: [CommandArgument] = []
        try content.withRestoredContents(access) { arguments = $0.arguments }
        return arguments
    }

    func restoredNotes() throws -> CommandValue? { try restoredArguments().first { $0.parameter == .notes }?.value }
}
