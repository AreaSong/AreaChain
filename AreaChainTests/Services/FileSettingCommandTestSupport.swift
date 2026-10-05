import Foundation
import Testing
@testable import AreaChain

@MainActor
final class FileSettingCommandFixture {
    nonisolated static let paths = ["/setting/language/english", "/setting/appearance/dark",
                        "/setting/title-truncation/middle", "/setting/capture-source/true"]
    let io: AppPreferencesFileFixture
    let store: LocalPreferenceFileStore
    let prefs: AppPreferences
    let handoff: HandoffFixture
    let adapter: FileLocalSettingCommandAdapter

    init(fault: LocalPreferenceFileFault? = nil) throws {
        io = try AppPreferencesFileFixture()
        let record = try io.legacy.files.seed()
        store = try io.legacy.files.store(fault)
        prefs = AppPreferences(defaults: io.legacy.defaults, fileStore: store,
                               startup: .ready(record, cleanupPending: false), effects: io.effects)
        handoff = try HandoffFixture()
        adapter = try FileLocalSettingCommandAdapter(coordinator: handoff.coordinator, filePreferences: prefs)
        io.resetEffects()
    }

    func state() throws -> CommandHostSession { try handoff.state() }
    func owned() throws -> CommandOwnedHost { try handoff.owned() }
    func unit() throws -> CommandExecutionUnit { try #require(state().execution?.units.first) }

    @discardableResult
    func queue(_ path: String, individual: Bool = false) throws -> UUID {
        let parsed = CommandPathParser().parse(.init(text: path))
        let command = try #require(parsed.command)
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: command.id, arguments: parsed.arguments)
        try handoff.start(draft)
        if individual { try adapter.prepare(#require(state().operations.active?.stamp), expecting: owned().lease) }
        let id = UUID()
        try handoff.send(.enqueue(#require(state().operations.active?.stamp), itemID: id, plan: state().plan.stamp))
        return id
    }

    @discardableResult
    func group(_ count: Int = 2, prepare: Bool = true) throws -> UUID {
        var members: [UUID] = []
        for path in Self.paths.prefix(count) { members.append(try queue(path)) }
        let id = UUID()
        try handoff.plan(.atomicGroup(id, members: members))
        if prepare { try prepareGroup() }
        return id
    }

    @discardableResult
    func prepareGroup() throws -> CommandPreferenceGroupBaseline {
        try adapter.prepareGroup(plan: state().plan.stamp, expecting: owned().lease)
    }

    func request() throws -> FileLocalSettingCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: owned().lease, identity: #require(state().execution?.preferenceGroupIdentity()), attempt: attempt)
    }

    func submit() throws -> FileLocalSettingCommandReport {
        try adapter.submit(plan: state().plan.stamp, expecting: owned().lease)
    }

    func external(_ changes: [LocalPreferenceValue]) throws {
        let store = try io.legacy.files.store()
        let current = try io.legacy.files.current()
        guard case .committed = store.commit(basedOn: current, changes: changes) else {
            throw LocalPreferenceFileIssue.invalidRequest
        }
    }
}
