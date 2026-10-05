import AppKit
import Testing
@testable import AreaChain

@MainActor
final class UnifiedSearchFileSettingFixture {
    let io: AppPreferencesFileFixture
    let store: LocalPreferenceFileStore
    let prefs: AppPreferences
    let results: UnifiedSearchResultsFixture
    var controller: UnifiedSearchController { results.controller }
    var files: LocalPreferenceFileFixture { io.legacy.files }

    init(fault: LocalPreferenceFileFault? = nil, ready: Bool = true) throws {
        io = try AppPreferencesFileFixture()
        let record = try io.legacy.files.seed()
        store = try io.legacy.files.store(fault)
        prefs = AppPreferences(defaults: io.legacy.defaults, fileStore: store,
            startup: ready ? .ready(record, cleanupPending: false) : .notMigrated(readOnly: LocalPreferenceFileFixture.values), effects: io.effects)
        results = try UnifiedSearchResultsFixture(filePreferences: prefs)
        io.resetEffects()
    }

    func stop() { results.stop() }
    var report: FileLocalSettingCommandReport { get throws { try #require(controller.fileSettingReport) } }
    var unit: CommandExecutionUnit { get throws { try #require(controller.settingExecution?.units.first) } }

    func start(_ index: Int, noChange: Bool = false) throws {
        try results.startOperation(UnifiedSearchSettingSamples.ids[index])
        let initial: [CommandValue] = [.choice("system"), .choice("system"), .choice("tail"), .boolean(false)]
        let target: [CommandValue] = [.choice("english"), .choice("dark"), .choice("middle"), .boolean(true)]
        let parameter: CommandParameterID = index == 3 ? .enabled : .value
        try #require(controller.editParameter(.init(parameter: parameter, operation: .assign,
            value: noChange ? initial[index] : target[index]), source: controller.buffer) != nil)
    }

    func queue(_ count: Int = 2, unchanged: Set<Int> = []) throws {
        for index in 0..<count {
            try start(index, noChange: unchanged.contains(index))
            try enqueue()
        }
    }

    func enqueue() throws {
        try #require(controller.enqueue(#require(controller.operations?.active?.stamp), source: controller.buffer))
    }

    func prepare() { controller.requestFileSettingPreparation(controller.buffer) }
    func submit() { controller.requestOperationSubmit(controller.buffer) }

    func external(_ changes: [LocalPreferenceValue]) throws {
        guard case .committed = try files.store().commit(basedOn: files.current(), changes: changes) else {
            throw LocalPreferenceFileIssue.invalidRequest
        }
    }

    func host(count: Int = 2) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: count == 3 ? .compact : .standard, width: count == 3 ? 304 : 620,
            locale: count == 4 ? "zh-Hans" : "en", dark: count != 2, results: controller, operations: true)
        try await host.start()
        return host
    }

    func expectSaved(_ count: Int, unchanged: Set<Int> = []) throws {
        let record = try files.current()
        var expected = LocalPreferenceFileFixture.values
        for (index, value) in AppPreferencesFileFixture.changes.prefix(count).enumerated() where !unchanged.contains(index) {
            expected.set(value)
        }
        #expect(record.values == expected)
        #expect(AppPreferencesFileFixture.values(prefs) == expected)
        #expect(store.metrics.snapshot().commits == 1 && store.metrics.snapshot().replacements == 1)
        #expect(io.events.count == 1)
        #expect(io.legacy.oldFourKeys().allSatisfy { $0 == .missing })
        #expect(try unit.local == .committed)
    }
}
