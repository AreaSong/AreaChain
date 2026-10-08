import AppKit
import CoreGraphics
import SwiftUI
import Testing
@testable import AreaChain

/// P 人工验收只组合既有隔离夹具；窗口、监听与合成状态在原 Gallery 结束时一并释放。
@MainActor @Observable
final class ControlsPlatformAcceptance {
    enum Scene: String, CaseIterable {
        case passwordTyping = "密码逐字 / Password typing"
        case passwordReplacement = "密码同值覆盖 / Password replacement"
        case capture = "输入与提交 / Capture"
        case search = "普通搜索 / Search"
        case clipboard = "剪贴板搜索 / Clipboard"
        case week = "窄周 / Week"
        case dashboard = "总览 / Dashboard"
        case bubble = "手记气泡 / Bubble"
        case nativeStepper = "原生长按 / NSStepper"
        case daybookStepper = "公共长按 / Daybook"
    }

    enum State: String { case idle, running, windingDown, closing, ended }
    enum EndReason: String { case completed, galleryClosed, deadline, cancelled, fixtureError, evidenceFailure, error }
    // 30 秒供人工停止输入并核对计数；不增加 600 秒总预算，也不启用任何桌面调用。
    nonisolated static let maximumSeconds: TimeInterval = 600
    nonisolated static let windDownSeconds: TimeInterval = 30
    var selection = Scene.capture
    var searchConsumer = SearchMultilineConsumer.workspace
    var middleInsertion = false
    var dark = false
    var chinese = true
    private(set) var state = State.idle
    private(set) var status = "仅合成内容 / Synthetic data only"
    private(set) var fixtureFailures = 0
    private(set) var recordedOpens = 0
    private(set) var generation = 0
    private(set) var lastCallback = "尚无回调 / No callback"
    private(set) var deadline: TimeInterval = 0
    private(set) var auxiliary: NSWindow?
    private(set) var input: SearchMultilineFixture?
    private(set) var activeStamp: ControlsPlatformEvents.WindowStamp?
    let evidence: ControlsPlatformEvidence
    let events: ControlsPlatformEvents
    var beforeOpen: (() throws -> Void)?
    private let now: () -> TimeInterval
    private var gallery: NSWindow?
    private var galleryStamp: ControlsPlatformEvents.WindowStamp?
    private var cleanup: (() -> Void)?
    private(set) var stepper: StepperProbe?
    private(set) var password: ControlsPlatformPassword?
    private var stepperPressed = false
    private var releaseObservationAt: TimeInterval?
    private var monitor: Any?
    private var galleryObserver: NSObjectProtocol?
    private var auxiliaryObserver: NSObjectProtocol?
    private var opened: Scene?
    private var lastInputSample: NSDictionary?
    var evidenceURL: URL? { state == .idle ? nil : evidence.url }
    var activeWindowNumber: Int? { auxiliary?.windowNumber }
    var canOpen: Bool { state == .running && evidence.failure == nil }
    var listenersReleased: Bool { monitor == nil && galleryObserver == nil && auxiliaryObserver == nil && events.listenerReleased }
    var todoCount: Int { input?.draft.commits ?? 0 }
    var diaryCount: Int { input?.draft.diaryCommits ?? 0 }
    var identityLabel: String { "\(evidence.runID) · scene \(generation) · \(activeStamp?.id ?? galleryStamp?.id ?? "—")" }
    var currentScene: String { (opened?.rawValue ?? "Gallery") + (input.map { " · \($0.kind.rawValue)" } ?? "") }

    init(evidence: ControlsPlatformEvidence? = nil,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        let evidence = evidence ?? ControlsPlatformEvidence()
        self.evidence = evidence
        self.now = now
        events = ControlsPlatformEvents(evidence)
    }

    func start(gallery: NSWindow, seconds: TimeInterval = maximumSeconds) {
        guard state == .idle else { return }
        self.gallery = gallery
        galleryStamp = .init(generation: 0, scene: "gallery", number: gallery.windowNumber)
        deadline = now() + min(Self.maximumSeconds, max(0, seconds))
        state = .running
        evidence.start()
        record("ready", ["deadlineUptime": deadline, "windDownSeconds": Self.windDownSeconds,
                         "executable": Bundle.main.executableURL?.path ?? "unknown",
                         "xctest": ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil])
        guard evidence.failure == nil else { close(reason: .evidenceFailure); return }
        events.start()
        galleryObserver = observeClose(gallery)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .keyDown, .keyUp]) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
            return event
        }
        status = "运行中 / Running"
    }

    func tick() {
        guard state == .running || state == .windingDown else { return }
        if evidence.failure != nil { close(reason: .evidenceFailure); return }
        if now() >= deadline { close(reason: .deadline); return }
        recordInputSample()
        password?.tick()
        if let releaseObservationAt, now() >= releaseObservationAt {
            self.releaseObservationAt = nil
            stepper?.trace?.mark("release-observation", value: stepper.map { Double($0.integer) })
        }
        if now() >= deadline - Self.windDownSeconds && state == .running {
            state = .windingDown
            status = "收尾期：停止新操作，核对计数；到期自动关闭 / Winding down: check counts, automatic close at deadline"
            if let auxiliary { auxiliary.title = "收尾期 / Winding down · \(auxiliary.title)" }
            record("winding-down", ["deadlineUptime": deadline])
        }
    }

    func waitUntilFinished() async throws {
        do {
            while state == .running || state == .windingDown {
                tick()
                if state == .ended { break }
                try await Task.sleep(for: .milliseconds(100))
            }
        } catch {
            close(reason: error is CancellationError ? .cancelled : .error)
            throw error
        }
    }

    func openSelected() {
        tick()
        guard canOpen else { return }
        closeAuxiliary(reason: "scene-switch")
        generation += 1
        opened = selection
        lastCallback = "尚无回调 / No callback"
        do {
            try beforeOpen?()
            switch selection {
            case .passwordTyping, .passwordReplacement: try openPassword()
            case .capture: try openInput(.capture)
            case .search: try openInput(searchConsumer)
            case .clipboard: try openInput(.clipboard)
            case .week: try openWeek()
            case .dashboard:
                let fixture = try DashboardScrollTestSupport(locale: locale, scheme: scheme,
                    size: NSSize(width: 680, height: 520))
                auxiliary = fixture.window
                cleanup = { fixture.close() }
            case .bubble: try openBubble()
            case .nativeStepper, .daybookStepper: try openStepper()
            }
            finishOpen()
        } catch {
            fixtureFailures += 1
            status = "QA 装配失败 / Fixture failed"
            record("fixture-error")
            close(reason: .fixtureError)
        }
    }

    private func finishOpen() {
        guard let auxiliary else { close(reason: .fixtureError); return }
        let stamp = ControlsPlatformEvents.WindowStamp(generation: generation, scene: currentScene,
                                                        number: auxiliary.windowNumber)
        activeStamp = stamp
        auxiliary.title = "P QA · \(evidence.runID) · g\(generation) · \(stamp.id) · \(currentScene)"
        auxiliary.styleMask.insert(.closable)
        auxiliary.center()
        (auxiliary as? ControlsEvidenceWindow)?.platform = self
        input?.draft.didSubmit = { [weak self, weak auxiliary] submission in
            guard let self, let auxiliary, self.accepts(auxiliary, stamp: stamp) else { return }
            self.lastCallback = self.events.submitted(submission, stamp: stamp)
        }
        auxiliaryObserver = observeClose(auxiliary)
        auxiliary.makeKeyAndOrderFront(nil)
        status = "已打开 / Open: \(selection.rawValue)"
        recordedOpens += 1
        record("open", ["locale": locale, "dark": dark, "canBecomeKey": auxiliary.canBecomeKey,
                        "canBecomeMain": auxiliary.canBecomeMain, "onActiveSpace": auxiliary.isOnActiveSpace,
                        "style": auxiliary.styleMask.rawValue, "width": auxiliary.frame.width,
                        "height": auxiliary.frame.height, "visible": auxiliary.isVisible,
                        "key": auxiliary.isKeyWindow, "appActive": NSApp.isActive])
        recordInputSample()
    }

    func recordObservation() {
        guard state == .running || state == .windingDown || state == .closing else { return }
        var values: [String: Any] = [:]
        if let input {
            values.merge(input.inputEvidence()) { _, new in new }
        }
        password?.sample("manual-observation")
        if let stepper { values["integer"] = stepper.integer; values["writes"] = stepper.writes }
        record("observation", values)
    }

    // 原有 100ms 生命周期 tick 只取标量；不是事件因果，也不保证捕获两个 tick 间的中间态。
    func recordInputSample() {
        guard state == .running || state == .windingDown, let input, activeStamp != nil else { return }
        let values = input.inputEvidence()
        let sample = values as NSDictionary
        guard lastInputSample != sample else { return }
        lastInputSample = sample
        record("input-state", values)
    }

    func close(reason: EndReason = .completed) {
        guard state != .closing && state != .ended else { return }
        let started = state != .idle
        state = .closing
        if started { record("closing", ["reason": reason.rawValue]) }
        closeAuxiliary(reason: reason.rawValue)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        events.stop()
        if let galleryObserver { NotificationCenter.default.removeObserver(galleryObserver) }
        galleryObserver = nil
        if let galleryStamp { events.detach(galleryStamp) }
        if let gallery { SystemPageHost.release(gallery) }
        gallery = nil
        if started {
            record("closed", ["reason": reason.rawValue, "auxiliaryReleased": auxiliary == nil,
                              "monitorReleased": listenersReleased, "galleryReleased": gallery == nil])
            evidence.finish()
        }
        state = .ended
        status = evidence.failure.map { "证据不完整 / Evidence incomplete: \($0)" } ?? "已结束 / Ended"
    }

    func windowClosed(_ window: NSWindow, stamp: ControlsPlatformEvents.WindowStamp) {
        guard state == .running || state == .windingDown else { return }
        if window === gallery && stamp == galleryStamp { close(reason: .galleryClosed) }
        else if accepts(window, stamp: stamp) { closeAuxiliary(reason: "window-closed") }
    }

    private func observeClose(_ window: NSWindow) -> NSObjectProtocol {
        let stamp = window === gallery ? galleryStamp : activeStamp
        return NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let window, let stamp else { return }
                self?.windowClosed(window, stamp: stamp)
            }
        }
    }

    private func closeAuxiliary(reason: String) {
        guard auxiliary != nil || cleanup != nil else { return }
        recordObservation()
        if let trace = stepper?.trace {
            for item in trace.items {
                record("stepper-trace", ["time": item.time, "phase": item.kind, "value": item.value as Any? ?? NSNull(),
                                         "increase": item.increase as Any? ?? NSNull(),
                                         "eventTimestamp": item.eventTimestamp as Any? ?? NSNull()])
            }
        }
        if let auxiliaryObserver { NotificationCenter.default.removeObserver(auxiliaryObserver) }
        auxiliaryObserver = nil
        (auxiliary as? ControlsEvidenceWindow)?.platform = nil
        input?.draft.didSubmit = nil
        let release = cleanup
        cleanup = nil
        release?()
        record("scene-closed", ["reason": reason])
        if let activeStamp { events.detach(activeStamp) }
        auxiliary = nil
        input = nil
        lastInputSample = nil
        stepper = nil
        stepperPressed = false
        releaseObservationAt = nil
        password = nil
        activeStamp = nil
        opened = nil
    }

    private var locale: String { chinese ? "zh-Hans" : "en" }
    private var scheme: ColorScheme { dark ? .dark : .light }

    private func openInput(_ kind: SearchMultilineConsumer) throws {
        let fixture = try SearchMultilineFixture(kind, locale: locale, scheme: scheme, platform: self)
        if middleInsertion && kind != .capture {
            (fixture.observedField?.delegate as? DaybookTextField.Coordinator)?.parent.text = "头🧪尾"
        }
        input = fixture
        auxiliary = fixture.window
        cleanup = { fixture.cleanup() }
    }

    private func openWeek() throws {
        let fixture = try CalendarWeekTestSupport(day: "2026-10-07")
        let todos = fixture.days.flatMap { day in
            (0..<24).map { TodoItem(title: "Synthetic \(day) / \($0)", dayKey: day) }
        }
        todos.forEach { fixture.fixture.container.mainContext.insert($0) }
        try fixture.fixture.container.mainContext.save()
        let board = CalendarWeekBoard(days: fixture.days, selectedKey: fixture.selected, todayKey: fixture.today,
            routines: [], checks: [], todos: todos, listFocused: false, listFocusID: .constant(nil),
            onSelect: { _ in }, onInspect: { _, _ in }, onReturnToGrid: {}, onDropTodo: { _, _ in })
        let window = fixture.fixture.window(board, locale: locale, scheme: scheme,
                                            size: NSSize(width: 700, height: 420))
        auxiliary = window
        cleanup = { SystemPageHost.release(window); fixture.cleanup() }
    }

    private func openBubble() throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let entries = (0..<2).map { index in
            DiaryEntry(text: "Synthetic \(index) " + String(repeating: "合成长标题 ", count: 12), dayKey: "2026-10-07")
        }
        entries.forEach { fixture.container.mainContext.insert($0) }
        try fixture.container.mainContext.save()
        let content = VStack(spacing: 12) {
            Text("仅悬停与观察；此宿主不要点复制或菜单。")
            Spacer().frame(height: 220)
            ForEach(entries) { entry in
                DiarySummaryRow(entry: entry, onSelect: {}, onDelete: {})
            }
            Spacer()
        }.padding(32)
        let window = fixture.window(content, locale: locale, scheme: scheme,
                                    size: NSSize(width: 380, height: 560))
        auxiliary = window
        cleanup = { SystemPageHost.release(window); fixture.cleanup() }
    }

    private func openPassword() throws {
        let support = ControlsPlatformPassword(replacement: selection == .passwordReplacement, locale: locale)
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let window = fixture.window(support.content, locale: locale, scheme: scheme,
                                    size: NSSize(width: 620, height: 300))
        auxiliary = window
        password = support
        support.host = window
        support.record = { [weak self] kind, values in self?.record(kind, values) }
        cleanup = { support.close(); SystemPageHost.release(window); fixture.cleanup() }
    }

    private func openStepper() throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let state = StepperProbe()
        state.integer = 500
        state.trace = StepperEventTrace()
        stepper = state
        let content = ControlsPlatformStepperView(state: state, native: selection == .nativeStepper) { initial in
            guard self.stepper === state, self.state == .running || self.state == .windingDown else { return }
            state.integer = initial
            self.record("stepper-reset", ["value": initial])
        }
        let window = fixture.window(content, locale: locale, scheme: scheme,
                                    size: NSSize(width: 600, height: 360))
        auxiliary = window
        cleanup = { SystemPageHost.release(window); fixture.cleanup() }
    }

    private func accepts(_ window: NSWindow, stamp: ControlsPlatformEvents.WindowStamp) -> Bool {
        (state == .running || state == .windingDown) && window === auxiliary && stamp == activeStamp
    }

    private func stamp(for window: NSWindow?) -> ControlsPlatformEvents.WindowStamp? {
        guard state == .running || state == .windingDown, let window else { return nil }
        if window === gallery { return galleryStamp }
        if window === auxiliary { return activeStamp }
        return nil
    }

    private func editor(in window: NSWindow?) -> NSTextView? {
        guard let window, let editor = window.firstResponder as? NSTextView,
              let field = editor.delegate as? NSTextField, field.window === window,
              field.currentEditor() === editor, !(field is NSSecureTextField) else { return nil }
        return editor
    }

    func observe(_ event: NSEvent) {
        guard let stamp = stamp(for: event.window) else { return }
        if events.relevant(event, stamp: stamp) { recordInputSample() }
        events.observe(event, stamp: stamp, editor: editor(in: event.window))
        observeStepper(event)
    }

    private func observeStepper(_ event: NSEvent) {
        guard let window = auxiliary, event.window === window, let stepper,
              let activeStamp, event.timestamp >= activeStamp.openedUptime else { return }
        // NSStepper 可能在内部 tracking 消费 mouseUp；返回后收到的其他 up 不能补造该次释放。
        if opened == .nativeStepper, stepperPressed,
           stepper.trace?.items.last?.kind == "native-trackingReturned" {
            stepperPressed = false
            stepper.trace?.mark("release-unobserved")
        }
        if event.type == .leftMouseDown {
            stepperPressed = ControlsStepperHit.contains(event.locationInWindow, in: window,
                                                         native: opened == .nativeStepper)
            releaseObservationAt = nil
            if stepperPressed { stepper.trace?.mark("observed-down", eventTimestamp: event.timestamp) }
        } else if event.type == .leftMouseUp, stepperPressed {
            stepperPressed = false
            stepper.trace?.mark("observed-up", eventTimestamp: event.timestamp)
            releaseObservationAt = now() + 2
        }
    }

    func withDispatch<T>(_ event: NSEvent, in window: NSWindow, action: () -> T) -> T {
        guard let stamp = stamp(for: window) else { return action() }
        let samples = events.relevant(event, stamp: stamp)
        defer { if samples { recordInputSample() } }
        return events.withDispatch(event, stamp: stamp, editor: editor(in: window), action: action)
    }

    private func record(_ kind: String, _ values: [String: Any] = [:]) {
        var row = (activeStamp ?? galleryStamp)?.fields ?? [:]
        row.merge(values) { _, new in new }
        evidence.record(kind, row)
    }
}

struct ControlsPlatformFeedback: View {
    @Bindable var session: ControlsPlatformAcceptance
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.currentScene).font(DaybookType.body.weight(.semibold))
            Text(session.identityLabel).font(DaybookType.caption).textSelection(.enabled)
            Text("待办 / Todo: \(session.todoCount) · 手记 / Diary: \(session.diaryCount)")
                .accessibilityIdentifier("qa.capture.counts")
            Text(session.lastCallback).accessibilityIdentifier("qa.capture.callback")
            Text("这是合成计数宿主；提交后保留草稿，不创建生产列表记录。")
            Text("Synthetic counters; submitting keeps the draft and creates no production records.")
            Text(session.evidence.failure.map { "证据不完整 / Evidence incomplete: \($0)" } ?? session.status)
                .accessibilityIdentifier("qa.lifecycle.status")
        }.font(DaybookType.caption).foregroundStyle(DaybookPalette.text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ControlsPlatformToolbar: View {
    @Bindable var session: ControlsPlatformAcceptance
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("P 验收 / QA", selection: $session.selection) {
                    ForEach(ControlsPlatformAcceptance.Scene.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("中文 / ZH", isOn: $session.chinese)
                Toggle("深色 / Dark", isOn: $session.dark)
                Button("打开 / Open") { session.openSelected() }.disabled(!session.canOpen)
                Button("记录计数 / Record") { session.recordObservation() }.disabled(session.state == .ended)
            }
            HStack {
                Picker("搜索宿主 / Host", selection: $session.searchConsumer) {
                    ForEach(SearchMultilineConsumer.ordinarySearches, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("下次打开设中段初值 / Middle initial value", isOn: $session.middleInsertion)
            }
            Text("Record 会切换焦点；连续输入无需点击。 / Record changes focus; input is sampled automatically.")
                .font(DaybookType.caption)
            ControlsPlatformFeedback(session: session)
        }.padding(8)
    }
}
