import Foundation
import Testing
@testable import AreaChain

/// 每个夹具从构造起隔离四键、外观和事件；计数包裹实际共享入口使用的存储调用。
@MainActor
final class PreferenceCommandIO {
    enum Failure: Error { case injected }
    enum WriteMode { case normal, drop, throwBefore, throwAfter, unreadableAfter, throwAfterUnreadable }
    let local: LocalPreferenceTestSupport
    var writes: [LocalPreferenceValue] = []
    var reads = 0
    var mode = WriteMode.normal
    var unreadable = false
    var failAppearance = false
    var failEvent = false
    var onRead: ((LocalPreferenceField, Int) throws -> Void)?
    var onWrite: (() -> Void)?
    var onAppearance: (() -> Void)?
    var onEvent: (() -> Void)?

    init() throws { local = try LocalPreferenceTestSupport() }

    func preferences() -> AppPreferences {
        var storage = LocalPreferenceStorage(defaults: local.defaults)
        let read = storage.read, write = storage.write
        storage.read = { [unowned self] field in
            reads += 1
            try onRead?(field, reads)
            if unreadable { throw Failure.injected }
            return try read(field)
        }
        storage.write = { [unowned self] value in
            writes.append(value)
            onWrite?()
            if mode == .throwBefore { throw Failure.injected }
            if mode != .drop { try write(value) }
            if mode == .throwAfter { throw Failure.injected }
            if mode == .unreadableAfter { unreadable = true }
            if mode == .throwAfterUnreadable { unreadable = true; throw Failure.injected }
        }
        let effects = LocalPreferenceEffects(applyAppearance: { [unowned self] value in
            local.appearances.append(value)
            onAppearance?()
            if failAppearance { throw Failure.injected }
        }, post: { [unowned self] notification in
            local.events.append(notification)
            onEvent?()
            if failEvent { throw Failure.injected }
            local.center.post(notification)
        })
        return AppPreferences(defaults: local.defaults, localStorage: storage, effects: effects)
    }

    func resetCounts() { writes = []; reads = 0; local.events = []; local.appearances = [] }
    func cleanup() { local.cleanup() }
}

@MainActor
final class LocalSettingCommandFixture {
    let io: PreferenceCommandIO
    let prefs: AppPreferences
    let handoff: HandoffFixture
    let adapter: LocalSettingCommandAdapter

    init(io: PreferenceCommandIO? = nil) throws {
        let io = try io ?? PreferenceCommandIO()
        self.io = io
        prefs = io.preferences()
        handoff = try HandoffFixture()
        adapter = LocalSettingCommandAdapter(coordinator: handoff.coordinator, preferences: prefs)
        io.resetCounts()
    }

    func cleanup() { io.cleanup() }
    func owned() throws -> CommandOwnedHost { try handoff.owned() }
    func state() throws -> CommandHostSession { try handoff.state() }

    @discardableResult
    func queue(_ command: String = "setting.language", value: CommandValue = .choice("english"),
               realBaseline: Bool = true) throws -> UUID {
        let parameter: CommandParameterID = command == "setting.captureSource" ? .enabled : .value
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            arguments: [.init(parameter: parameter, operation: .assign, value: value)])
        try handoff.start(draft)
        if realBaseline {
            try adapter.prepare(#require(state().operations.active?.stamp), expecting: owned().lease)
        }
        let id = UUID()
        try handoff.send(.enqueue(#require(state().operations.active?.stamp), itemID: id, plan: state().plan.stamp))
        return id
    }

    func request() throws -> LocalSettingCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: owned().lease, operation: #require(state().execution?.operation(attempt.unitID)), attempt: attempt)
    }

    func submit() throws -> LocalSettingCommandReport {
        try adapter.submit(plan: state().plan.stamp, expecting: owned().lease)
    }

    func unit() throws -> CommandExecutionUnit { try #require(state().execution?.units.first) }
}
