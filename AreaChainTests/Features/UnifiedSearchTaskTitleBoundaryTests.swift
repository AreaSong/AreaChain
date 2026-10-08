import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskTitleBoundaryTests {
    @Test(arguments: [0, 1, 2, 3, 4, 5, 6]) func nativeAcceptedConflictsRetainInput(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start("合成修改 #恢复 !p1 @09:30")
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await host.prepareAndAcceptTitle(fixture)
        switch kind {
        case 0: fixture.base.todo.title = "外部新标题"
        case 1: fixture.base.todo.isUrgent.toggle()
        case 2: fixture.base.deleted.name = "已改名"
        case 3: fixture.base.deleted.deletedAt = nil
        case 4: fixture.base.live.isPrivateDiary = true
        case 5: fixture.base.todo.deletedAt = Date(timeIntervalSince1970: 999)
        default: fixture.base.io.context.insert(TodoItem(id: fixture.base.todo.id, title: "重复身份", dayKey: "2026-10-05"))
        }
        try fixture.base.io.context.save()
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.currentTaskTitleAcceptance == nil && fixture.controller.settingExecution == nil)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        #expect(fixture.controller.taskTitleFailure != nil)
        try fixture.noWrites()
        try await host.revealSettingControlInsidePanel("unified.title.issue")
        try host.snapshot("title-conflict-\(kind)")
    }

    @Test func nativeDirtyContextRetainsOriginalUnsavedEdits() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        _ = try await host.prepareAndAcceptTitle(fixture)
        fixture.base.todo.dueMinutes = 777
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.taskTitleFailure == "unified.title.dirty")
        #expect(fixture.base.io.context.hasChanges && fixture.base.todo.dueMinutes == 777)
        #expect(try fixture.stored.dueMinutes == 600 && fixture.stored.title == "原标题")
        #expect(fixture.controller.plan?.items.first?.draft.arguments.first?.value == .shortText("合成修改"))
        try fixture.noWrites()
    }

    @Test(arguments: [0, 1, 2]) func nativeUnknownAndLocalSavedExternalFailure(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start("合成修改 #新建 #恢复")
        let host = try await fixture.host()
        defer { host.close() }
        _ = try await host.prepareAndAcceptTitle(fixture)
        if kind == 0 { fixture.io.saveMode = .throwAfter }
        if kind == 1 { fixture.environment.afterPublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 2 { fixture.io.notificationResult = .failed; fixture.io.calendarResult = .failed }
        try await host.clickCompositionControl("unified.title.save")
        let facts = try fixture.facts
        #expect(facts.state == (kind == 0 ? .unknown : .saved))
        #expect(try fixture.stored.title == "合成修改" && fixture.count("save") == 1)
        if kind == 0 {
            try await host.clickCompositionControl("unified.title.verify")
            #expect(fixture.controller.taskTitleVerification?.presence == .live)
            #expect(try fixture.facts == facts)
        }
        if kind == 1 { #expect(facts.publicationFailed && facts.save == .returned) }
        if kind == 2 {
            #expect(fixture.controller.taskTitleUnit?.effects[.notification] == .failed)
            #expect(fixture.io.notificationProcessed == 1 && fixture.io.calendarProcessed == 1)
        }
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.count("save") == 1 && fixture.controller.plan?.items.isEmpty == true)
        try await host.revealSettingControlInsidePanel("unified.title.status")
        try host.snapshot("title-result-\(kind)")
    }

    @Test func nativeTargetSwitchInvalidatesAcceptanceAndPreservesText() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start("用户新标题 #新建")
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await host.prepareAndAcceptTitle(fixture)
        let old = fixture.controller.buffer
        let item = try #require(fixture.controller.plan?.items.first)
        try await host.clickCompositionControl("unified.plan.edit." + item.id.uuidString)
        try await host.clickCompositionControl("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        let oldPicker = try #require(fixture.controller.objectSelection?.stamp)
        // 新读取版本让旧候选回调失效，不能拿当前 lease 包装旧事件。
        _ = try await fixture.results.publish()
        #expect(!fixture.controller.acceptObjects(oldPicker))
        try await host.clickCompositionControl("unified.objects.cancel")
        let second = CommandObjectReference(type: .todo, id: UUID())
        fixture.base.io.context.insert(TodoItem(id: second.id, title: "另一合成任务", dayKey: "2026-10-05"))
        try fixture.base.io.context.save()
        fixture.results.batch.snapshots.todos = .complete([
            .init(id: fixture.base.todo.id, title: "原标题", isDone: true, dayKey: "2026-10-05", createdAt: TodoQueryFixture.created),
            .init(id: second.id, title: "另一合成任务", isDone: false, dayKey: "2026-10-05", createdAt: TodoQueryFixture.created)])
        try await host.clickCompositionControl("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        try await host.clickCompositionControl("unified.select." + second.searchIdentifier)
        try await host.clickCompositionControl("unified.objects.accept")
        await fixture.controller.objectSelectionTask?.value
        #expect(fixture.controller.editingDraft?.targets == .init(.single, objects: [second]))
        #expect(fixture.controller.editingDraft?.baseline == CommandDraftBaseline())
        #expect(fixture.controller.taskTitlePreview == nil && fixture.controller.taskTitleAcceptance == nil)
        #expect(fixture.controller.editingDraft?.arguments == accepted.preview.arguments)
        fixture.controller.acceptTaskTitle(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        try fixture.noWrites()
    }

    @Test(arguments: [false, true]) func nativeFocusOrPrivateLockRevokesAcceptance(locked: Bool) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await host.prepareAndAcceptTitle(fixture)
        let old = fixture.controller.buffer
        if locked { fixture.privacy.post(name: .privacyWillLock, object: fixture.results.vault) }
        else {
            let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false
            other.makeKeyAndOrderFront(nil)
            try await SystemPageHost.settle(other)
            SystemPageHost.release(other)
        }
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        #expect(panel.subviews.isEmpty && fixture.controller.taskTitleAcceptance == nil)
        fixture.controller.acceptTaskTitle(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        try fixture.noWrites()
        host.window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: host.window)
        if !locked {
            try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
            _ = try await fixture.results.publish()
        }
        #expect(fixture.controller.taskTitleAcceptance == nil)
    }

    @Test func transferredHostCannotUseOldAcceptance() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let accepted = try fixture.prepareAndAccept()
        let source = fixture.controller.buffer
        _ = try fixture.results.handoff.transfer()
        let receiver = try fixture.results.handoff.state(HandoffFixture.target)
        fixture.controller.acceptTaskTitle(accepted.preview, source: source)
        fixture.controller.requestOperationSubmit(source)
        #expect(try fixture.results.handoff.state(HandoffFixture.target) == receiver)
        try fixture.noWrites()
    }

    @Test(arguments: [0, 1, 2, 3]) func nativeClosedInputsAndMultiplePlans(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        let trace = TaskTitleNativeTrace(fixture)
        defer { trace.stop() }
        try await fixture.start()
        trace.record("kind=\(kind).started")
        if kind == 0 { fixture.io.notes = .unknown }
        if kind == 1 { fixture.base.protection = .unknown }
        if kind == 2 {
            try #require(fixture.controller.enqueue(try #require(fixture.controller.editingDraft?.stamp), source: fixture.controller.buffer))
            try fixture.results.startOperation("todo.create")
            try fixture.results.typeParameter(.title, text: "不可执行的第二项")
        }
        if kind == 3 {
            let draft = try #require(fixture.controller.editingDraft)
            _ = fixture.controller.sendOperation(.selectTargets(draft.stamp, .init(.selected,
                objects: [fixture.target, .init(type: .todo, id: UUID())])), source: fixture.controller.buffer)
        }
        let host = try await fixture.host()
        defer { host.close() }
        trace.host = host
        trace.record("kind=\(kind).hostReady")
        // T-M1 将混合创建/标题计划交给链面板；仅装配标题的宿主仍须拒绝整项计划。
        try await host.clickCompositionControl(kind == 2 ? "unified.chain.prepare" : "unified.title.prepare")
        trace.record("kind=\(kind).prepared")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        trace.record("kind=\(kind).commandReturn")
        #expect(fixture.controller.taskTitleAcceptance == nil && fixture.controller.settingExecution == nil)
        try fixture.noWrites()
        try await host.revealSettingControlInsidePanel(kind == 2 ? "unified.chain.issue" : "unified.title.issue")
        try host.snapshot("title-closed-\(kind)")
    }
}
