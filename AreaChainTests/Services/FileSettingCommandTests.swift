import Foundation
import Observation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct FileSettingCommandTests {
    @Test(arguments: FileSettingCommandFixture.paths)
    func fileSingleUsesParserAndCommonCommit(path: String) throws {
        let fixture = try FileSettingCommandFixture()
        let keys = fixture.io.legacy.oldFourKeys()
        try fixture.queue(path, individual: true)
        let original = try fixture.state().plan.items[0]
        let report = try fixture.submit()
        #expect(report.identity.unitID == original.id && report.identity.groupID == nil)
        #expect(fixture.store.metrics.snapshot().commits == 1 && fixture.store.metrics.snapshot().replacements == 1)
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .succeeded)
        #expect(try fixture.unit().preferenceWrite == nil)
        #expect(report.localReceipt.attempt.phase == .local && report.presentationReceipt?.attempt.phase == .external)
        #expect(fixture.io.events.count == 1 && fixture.io.legacy.oldFourKeys() == keys)
        #expect(try fixture.prefs.committedLocalPreferenceRecord == fixture.io.legacy.files.current())
    }

    @Test(arguments: [2, 3, 4])
    func explicitGroupUsesOneReadOneCommitAndOriginalIdentities(count: Int) throws {
        let fixture = try FileSettingCommandFixture()
        let group = try fixture.group(count, prepare: false)
        let before = try fixture.owned()
        let reads = fixture.store.metrics.snapshot().reads
        let evidence = try fixture.prepareGroup()
        let plan = try fixture.state().plan
        #expect(fixture.store.metrics.snapshot().reads == reads + 1)
        #expect(evidence.values.count == 4 && evidence.fieldRevisions.count == 4)
        #expect(plan.revision == before.session.plan.revision + 1)
        #expect(try fixture.owned().lease.revision == before.lease.revision + 1)
        #expect(evidence.members == plan.items.map(\.stamp) && evidence.groupID == group)
        #expect(plan.items.allSatisfy { $0.draft.baseline.preferenceGroup == evidence })
        let report = try fixture.submit()
        #expect(report.identity.unitID == group && report.identity.unitID != plan.items[0].id)
        #expect(report.identity.members == plan.items.map(\.stamp))
        #expect(fixture.store.metrics.snapshot().commits == 1 && fixture.store.metrics.snapshot().replacements == 1)
        #expect(fixture.io.events.count == 1 && fixture.io.appearances == [.dark])
        #expect(try fixture.unit().local == .committed && fixture.unit().members == plan.items.map(\.id))
        #expect(try fixture.unit().effects == [.preferencePresentation: .succeeded])
    }

    @Test func noChangeWritesNothingAndPartialChangeIsOneWholeRecord() throws {
        let unchanged = try FileSettingCommandFixture()
        let ids = try [unchanged.queue("/setting/language/system"), unchanged.queue("/setting/appearance/system")]
        try unchanged.handoff.plan(.atomicGroup(UUID(), members: ids))
        try unchanged.prepareGroup()
        let inventory = try unchanged.io.legacy.files.inventory()
        let report = try unchanged.submit()
        #expect(report.localReceipt.result == .preferenceGroupCommit(.noChange) && report.presentationReceipt == nil)
        #expect(try unchanged.io.legacy.files.inventory() == inventory)
        #expect(unchanged.store.metrics.snapshot().replacements == 0 && unchanged.io.events.isEmpty)
        #expect(throws: FileLocalSettingCommandIssue.notRetryable) {
            try unchanged.adapter.returnUnsubmittedToPlan(report.localReceipt.attempt, expecting: unchanged.owned().lease)
        }
        let partial = try FileSettingCommandFixture()
        let members = try [partial.queue("/setting/language/system"), partial.queue("/setting/appearance/dark")]
        try partial.handoff.plan(.atomicGroup(UUID(), members: members))
        try partial.prepareGroup()
        let changed = try partial.submit()
        let record = try partial.io.legacy.files.current()
        #expect(changed.changedFields == [.appearance])
        #expect(record.recordRevision == 2 && record.fieldRevisions.language == 2 && record.fieldRevisions.appearance == 2)
        #expect(partial.store.metrics.snapshot().commits == 1 && partial.store.metrics.snapshot().replacements == 1)
        #expect(partial.io.events.count == 1)
    }

    @Test func publishOnlyCompleteStatesAndLocalFactPrecedesObservationAndEffects() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group(4)
        let old = AppPreferencesFileFixture.values(fixture.prefs)
        var observations: [LocalPreferenceValues] = []
        withObservationTracking {
            _ = fixture.prefs.language
            _ = fixture.prefs.appearance
            _ = fixture.prefs.quadrantTitleTruncation
            _ = fixture.prefs.stampCaptureApp
        } onChange: {
            MainActor.assumeIsolated {
                observations.append(AppPreferencesFileFixture.values(fixture.prefs))
                #expect((try? fixture.unit().local) == .committed)
            }
        }
        fixture.io.onAppearance = {
            #expect((try? fixture.unit().local) == .committed)
            observations.append(AppPreferencesFileFixture.values(fixture.prefs))
        }
        fixture.io.onEvent = { observations.append(AppPreferencesFileFixture.values(fixture.prefs)) }
        _ = try fixture.submit()
        #expect(observations == [old, AppPreferencesFileFixture.changedValues, AppPreferencesFileFixture.changedValues])
        #expect(fixture.store.metrics.snapshot().replacements == 1)
    }

    @Test func fileBackendAndLegacyAdapterAreMutuallyExclusive() throws {
        let fixture = try FileSettingCommandFixture()
        let old = LocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, preferences: fixture.prefs)
        try fixture.group()
        #expect(!old.isAssembled(for: fixture.handoff.coordinator))
        #expect(throws: LocalSettingCommandIssue.unsupported) {
            try old.submit(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        let legacy = try LocalSettingCommandFixture()
        defer { legacy.cleanup() }
        #expect(throws: FileLocalSettingCommandIssue.unsupportedBackend) {
            try FileLocalSettingCommandAdapter(coordinator: legacy.handoff.coordinator, filePreferences: legacy.prefs)
        }
        try legacy.queue()
        _ = try legacy.submit()
        #expect(legacy.io.writes == [.language(.english)])
        #expect(fixture.store.metrics.snapshot().commits == 0)
    }
}
