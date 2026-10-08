import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchTaskTitleFixture {
    let io: TaskTitleCommandIO
    let environment: TaskTitleCommandEnvironment
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    var base: TaskTitleFixture { io.base }
    var target: CommandObjectReference { .init(type: .todo, id: base.todo.id) }

    init(assembled: Bool = true) throws {
        io = try TaskTitleCommandIO()
        environment = try io.environment()
        var batch = QueryBatchFixture.empty("/tasks")
        // 候选是合成任务的安全标题投影，不读取 notes 或完整 snapshot。
        batch.snapshots.todos = .complete([.init(id: io.base.todo.id, title: io.base.todo.title,
            isDone: io.base.todo.isDone, dayKey: io.base.todo.dayKey, createdAt: io.base.todo.createdAt)])
        results = try .init(batch, privacyCenter: privacy, taskTitleEnvironment: assembled ? environment : nil)
    }

    func stop() { results.stop() }
    func count(_ value: String) -> Int { base.io.trace.filter { $0 == value }.count }
    var facts: CommandTaskTitleFacts { get throws { try #require(controller.settingExecution?.units.first?.taskTitle) } }
    var stored: TodoItem { get throws { try #require(base.io.readTodos().first { $0.id == base.todo.id }) } }

    func start(_ text: String = "合成修改") async throws {
        try results.startOperation("todo.title")
        try await results.acceptObjects([target])
        try results.typeParameter(.title, text: text)
        await controller.objectSelectionTask?.value
    }

    @discardableResult func prepareAndAccept() throws -> CommandTaskTitleAcceptance {
        controller.prepareTaskTitle(controller.buffer)
        let preview = try #require(controller.currentTaskTitlePreview, "标题准备失败")
        controller.acceptTaskTitle(preview, source: controller.buffer)
        return try #require(controller.currentTaskTitleAcceptance)
    }

    func noWrites() throws {
        #expect(count("save") == 0 && count("ui") == 0)
        #expect(base.io.authorizations.isEmpty && base.io.registered.isEmpty)
        #expect(io.notificationProcessed == 0 && io.calendarProcessed == 0)
    }

    func host(layout: UnifiedSearchInputLayout = .standard, width: CGFloat = 620,
              locale: String = "en", dark: Bool = false) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                         results: controller, operations: true)
        try await host.start()
        return host
    }
}

extension UnifiedSearchTestHost {
    func prepareAndAcceptTitle(_ fixture: UnifiedSearchTaskTitleFixture) async throws -> CommandTaskTitleAcceptance {
        try await clickCompositionControl("unified.title.prepare")
        let preview = try #require(fixture.controller.currentTaskTitlePreview,
            "标题准备失败：\(fixture.controller.taskTitleFailure ?? "none")")
        #expect(preview.impact.target == fixture.target)
        try fixture.noWrites()
        #expect(fixture.base.deleted.deletedAt == TaskTitleFixture.deletion)
        try await clickCompositionControl("unified.title.accept")
        try fixture.noWrites()
        #expect(fixture.base.deleted.deletedAt == TaskTitleFixture.deletion)
        return try #require(fixture.controller.currentTaskTitleAcceptance)
    }

    func selectTitleTarget(_ fixture: UnifiedSearchTaskTitleFixture, keyboard: Bool = false) async throws {
        try await clickCompositionControl("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await settle()
        if keyboard {
            window.makeFirstResponder(try field)
            try await settle()
            try await key(125, "\u{f701}")
            try await key(49, " ")
            try await key(48, "\t")
        } else {
            try await clickCompositionControl("unified.select." + fixture.target.searchIdentifier)
            try await clickCompositionControl("unified.objects.accept")
        }
        await fixture.controller.objectSelectionTask?.value
        try await settle()
        #expect(fixture.controller.editingDraft?.targets == .init(.single, objects: [fixture.target]))
        #expect(fixture.controller.editingDraft?.arguments.contains { $0.parameter == .parent || $0.parameter == .target } == false)
    }
}

/// 仅记录合成标题夹具的资格与窗口事件，避免把缺少控件直接归因为桌面失焦。
@MainActor final class TaskTitleNativeTrace {
    let fixture: UnifiedSearchTaskTitleFixture
    var host: UnifiedSearchTestHost?
    private var displayToken: UUID?
    private var windowTokens: [NSObjectProtocol] = []

    init(_ fixture: UnifiedSearchTaskTitleFixture) {
        self.fixture = fixture
        displayToken = fixture.results.session.displayUpdates.observe { [weak self] change in
            self?.record("display.\(change)")
        }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            windowTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    self?.record("\(note.name.rawValue).window=\((note.object as? NSWindow)?.windowNumber ?? -1)")
                }
            })
        }
    }

    func record(_ step: String) {
        let controller = fixture.controller
        let window = host?.window
        let nodes = SettingsButtonTestSupport.elements(window?.contentView)
        let panels = nodes.compactMap { $0 as? UnifiedSearchOperationBoundary }
        let identifiers = nodes.compactMap { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String }
        var qualification = "valid"
        do { try fixture.results.session.validateDisplayHost(expecting: controller.buffer.lease) }
        catch { qualification = String(describing: error) }
        print("TM1_TITLE_TRACE \(step) qualification=\(qualification) visible=\(controller.operationVisible) "
            + "active=\(NSApp.isActive) key=\(window?.isKeyWindow ?? false) window=\(window?.windowNumber ?? -1) "
            + "front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown") "
            + "panels=\(panels.map { "\(ObjectIdentifier($0)):\($0.subviews.count)" }) "
            + "draft=\(String(describing: controller.editingDraft?.stamp)) targets=\(controller.editingDraft?.targets.objects.count ?? -1) "
            + "title=\(controller.showsTaskTitle) identifiers=\(identifiers)")
    }

    func stop() {
        if let displayToken { fixture.results.session.displayUpdates.remove(displayToken) }
        windowTokens.forEach(NotificationCenter.default.removeObserver)
        windowTokens.removeAll()
    }
}
