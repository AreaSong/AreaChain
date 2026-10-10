import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchContentLifecycleTests {
    @Test(arguments: [0, 1, 2, 3, 4]) func nativeContentPreservesDraftPlanRunUnknownAndRevision(_ mode: Int) async throws {
        let fields = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fields)
        let f = try UnifiedSearchContentFixture(handoff: fields.handoff, multiPlan: adapter)
        defer { f.stop() }
        if mode < 4 {
            try MultiPlanRevisionSupport.queue(fields, kind: 0)
            try MultiPlanRevisionSupport.queue(fields, kind: 1)
            if mode == 2 { fields.io.saveMode = .throwAfter }
            if mode == 3 { fields.io.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected } }
            if mode > 0 { try MultiPlanRevisionSupport.start(adapter, fields.handoff, maximum: 1) }
            if mode == 3 { _ = try MultiPlanRevisionSupport.returnAll(adapter, fields.handoff) }
        }
        _ = f.controller.publishOperation(text: "/diaries")
        try await f.start()
        try await f.query("/diaries")
        if mode == 4 {
            _ = f.controller.beginOperation(.init(rawValue: "todo.title"), source: f.controller.buffer)
            _ = try await f.controller.readObjectSource()
        }
        let before = try fields.handoff.state()
        let history = fields.handoff.coordinator.revisionChain(HandoffFixture.source)
        let saves = fields.count("save"), events = fields.count("ui")
        let key = "todo-\(f.base.todo.id)"
        f.base.drafts.titles[key] = "尚未提交的标题"
        f.base.drafts.notes[key] = "尚未提交的备注"
        try await f.open(.init(type: .diary, id: f.diary.id))
        #expect(f.content.content != nil)
        #expect(try fields.handoff.state() == before)
        try await f.base.click("unified.navigation.return")
        #expect(try fields.handoff.state() == before)
        let afterHistory = fields.handoff.coordinator.revisionChain(HandoffFixture.source)
        #expect(afterHistory.count == history.count)
        for (before, after) in zip(history, afterHistory) {
            #expect(before.id == after.id && before.parent == after.parent && before.owner == after.owner)
            #expect(before.assemblyID == after.assemblyID && before.run == after.run && before.outputs == after.outputs)
        }
        #expect(fields.count("save") == saves && fields.count("ui") == events)
        #expect(f.base.drafts.titles[key] == "尚未提交的标题" && f.base.drafts.notes[key] == "尚未提交的备注")
        if mode == 2 { #expect(f.controller.settingExecution?.hasUnknownCommit == true) }
        if mode == 1 { #expect(f.controller.settingExecution?.units.first?.state == .succeeded) }
        try f.assertNoWrites()
    }

    @Test func actualSearchPositionAndSelectionSurviveDiaryRead() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        for index in 0..<45 { f.context.insert(DiaryEntry(text: "合成定位手记 \(index)", dayKey: f.base.day)) }
        try f.context.save(); f.base.saves = 0
        try await f.start()
        try await f.query("/diaries")
        let page = try f.session.presentation().pagination
        let object = try #require(page.snapshot.visible.first)
        f.controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: f.controller.buffer)
        f.controller.browse(.init(version: page.snapshot.version, action: .select(object, true)), source: f.controller.buffer)
        try await f.base.settle()
        let boundaries = SettingsButtonTestSupport.elements(f.base.window?.contentView).compactMap { $0 as? UnifiedSearchResultsBoundary }
        let boundary = try #require(boundaries.first)
        let scroll = try #require(SettingsButtonTestSupport.elements(boundary).compactMap { $0 as? NSScrollView }.first)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 240)); scroll.reflectScrolledClipView(scroll.contentView)
        try await f.base.settle()
        let before = try #require(f.controller.captureSearchScroll?())
        #expect(before.y > 0)
        try await f.open(object)
        try await f.base.click("unified.navigation.return")
        let after = try #require(f.controller.captureSearchScroll?())
        #expect(abs(before.y - after.y) < 1)
        #expect(try f.session.presentation().pagination.browse.selected == [object])
    }

    @Test func oldReadCannotClearNewContentAndFileChangesRevokePreview() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/images")
        var resume: CheckedContinuation<Void, Never>?
        var reader = f.content.reader
        reader.beforeImageRead = { await withCheckedContinuation { resume = $0 } }
        let content = WorkspaceContentSession(reader: reader)
        let publication = try f.session.presentation()
        try content.bindSource(content.captureSource(), publication: publication)
        let object = CommandObjectReference(type: .image, id: f.image.id)
        let open = ContentQueryBrowseOpen(object: object, parent: .init(type: .todo, id: f.base.todo.id), viewingTrash: false)
        let pending = Task { await content.open(open, session: f.session, lease: f.controller.buffer.lease,
                                              version: publication.pagination.snapshot.version) }
        for _ in 0..<100 where resume == nil { await Task.yield() }
        content.clear()
        try await f.query("/tags")
        let newPublication = try f.session.presentation()
        try content.bindSource(content.captureSource(), publication: newPublication)
        await content.open(.init(object: .init(type: .tag, id: f.tag.id), parent: nil, viewingTrash: false),
                           session: f.session, lease: f.controller.buffer.lease,
                           version: newPublication.pagination.snapshot.version)
        resume?.resume(); await pending.value
        guard case .tag(let current) = content.content else { Issue.record("迟到读取不得清掉新内容"); return }
        #expect(current.id == f.tag.id)
        try await f.query("/images")
        try await f.serviceOpen(object, parent: open.parent)
        #expect(f.content.content != nil)
        try Data("合成外部替换".utf8).write(to: f.store.fileURL(id: f.image.id))
        for _ in 0..<100 where f.content.content != nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(f.content.content == nil && f.content.failure == .stale)
    }

    @Test func nativeOwnerNavigationDoesNotInventRoutineOccurrence() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.start()
        f.image.ownerKind = "routine"; f.image.ownerID = f.base.routine.id
        try await f.query("/images")
        try await f.open(.init(type: .image, id: f.image.id))
        try await f.base.click("unified.content.openOwner")
        #expect(f.controller.contentOwnerMessage == "unified.content.ownerNeedsDay")
        #expect(f.content.content != nil && f.base.navigation.navigationObject == nil)
        try await f.base.back()
        f.image.ownerKind = "diary"; f.image.ownerID = f.diary.id
        try await f.query("/images")
        try await f.open(.init(type: .image, id: f.image.id))
        try await f.base.click("unified.content.openOwner")
        await f.controller.navigationTask?.value
        #expect(f.content.target == .init(type: .diary, id: f.diary.id))
        guard case .diary(let value) = f.content.content else { Issue.record("所属普通手记必须显示全文"); return }
        #expect(value.text == UnifiedSearchContentFixture.text)
        #expect(try f.context.fetch(FetchDescriptor<RoutineCheck>()).isEmpty)
        try await f.base.back()
        #expect(f.controller.buffer.text == "/images")
    }

    @Test func nativeMarkedTextAndReturnTabKeepOriginalInputContract() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.start()
        try await f.query("/tags")
        let page = try f.session.presentation().pagination
        f.controller.browse(.init(version: page.snapshot.version, action: .activate(.init(type: .tag, id: f.tag.id))), source: f.controller.buffer)
        try await f.base.typeNative("/go/ta")
        try await f.base.key(48, "\t")
        #expect(f.controller.returnSearch == nil)
        try await f.base.typeNative("/go/tag")
        let editor = try f.base.editor
        editor.setMarkedText("合成组合", selectedRange: NSRange(location: 0, length: 4), replacementRange: NSRange(location: 0, length: 0))
        f.controller.executeNavigation(source: f.controller.buffer)
        #expect(f.controller.returnSearch == nil || f.base.navigation.isSearching)
        #expect(editor.hasMarkedText())
        editor.unmarkText()
        try await f.query("/tags")
        let current = try f.session.presentation().pagination
        f.controller.browse(.init(version: current.snapshot.version, action: .activate(.init(type: .tag, id: f.tag.id))), source: f.controller.buffer)
        try await f.base.typeNative("/go/tag")
        try await f.base.key(36, "\r")
        if f.controller.returnSearch == nil { try await f.base.key(36, "\r") }
        await f.controller.navigationTask?.value
        #expect(f.content.content != nil)
        try await f.base.key(53, "\u{1b}")
        #expect(f.base.navigation.isSearching)
        try f.assertNoWrites()
    }
}
