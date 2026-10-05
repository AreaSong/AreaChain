import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchFileSettingContractTests {
    @Test(arguments: 2...4)
    func wholePreparationSubmissionAndDuplicateEvents(count: Int) throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(count)
        let source = fixture.controller.buffer
        #expect(fixture.controller.plan?.items.allSatisfy { $0.atomicGroup == nil } == true)
        fixture.prepare()
        #expect(fixture.controller.fileSettingIssue == nil)
        let plan = fixture.controller.plan
        fixture.prepare()
        fixture.controller.requestFileSettingPreparation(source)
        #expect(fixture.controller.plan == plan)
        let submit = fixture.controller.buffer
        fixture.submit()
        fixture.controller.requestOperationSubmit(submit)
        try fixture.expectSaved(count)
        #expect(try fixture.report.identity.groupID != fixture.report.identity.members.first?.id)
        let report = try fixture.report
        fixture.controller.fileSettingResultAction(.done, report: report, source: fixture.controller.buffer)
        #expect(fixture.controller.settingExecution == nil)
    }

    @Test func planRevisionInvalidatesEvidenceEvenWithoutChangingValues() throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue()
        fixture.prepare()
        let before = try #require(fixture.controller.plan)
        #expect(fixture.controller.sendPlan(.reorder(before.items.map(\.id)), source: fixture.controller.buffer))
        #expect(fixture.controller.fileSettingIssue == "unified.group.needsPreparation")
        fixture.submit()
        #expect(fixture.store.metrics.snapshot().commits == 0)
        fixture.prepare()
        #expect(fixture.controller.fileSettingIssue == nil)
        fixture.submit()
        try fixture.expectSaved(2)
    }

    @Test func oldSingleBaselineConflictSurvivesGroupPreparation() throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.start(0)
        fixture.prepare()
        try fixture.enqueue()
        try fixture.start(1)
        try fixture.enqueue()
        try fixture.external([.language(.chinese)])
        fixture.prepare()
        #expect(fixture.controller.plan?.items.count == 2)
        #expect(fixture.controller.fileSettingIssue == "unified.group.conflict")
        #expect(fixture.store.metrics.snapshot().commits == 0)
        fixture.controller.requestFileSettingConflict(fixture.controller.buffer)
        // 重读只展示冲突，明确确认才为完整组安装同份证据。
        let confirmation = try #require(fixture.controller.fileSettingConfirmation)
        #expect(fixture.controller.plan?.items.last?.draft.baseline.preferenceGroup == nil)
        fixture.controller.resolveFileSettingConflict(confirmation, choice: .confirmOverwrite)
        fixture.submit()
        try fixture.expectSaved(2)
    }

    @Test func duplicateMixedAndNotReadyStayIntact() throws {
        let duplicate = try UnifiedSearchFileSettingFixture()
        defer { duplicate.stop() }
        try duplicate.start(0); try duplicate.enqueue()
        try duplicate.start(0); try duplicate.enqueue()
        let plan = duplicate.controller.plan
        duplicate.prepare()
        #expect(duplicate.controller.plan == plan)
        #expect(duplicate.controller.fileSettingIssue == "unified.group.duplicates")
        let mixed = try UnifiedSearchFileSettingFixture()
        defer { mixed.stop() }
        try mixed.start(0); try mixed.enqueue()
        try mixed.results.startOperation("clipboard.limit")
        try mixed.enqueue()
        let original = mixed.controller.plan
        mixed.prepare(); mixed.submit()
        #expect(mixed.controller.plan == original && mixed.store.metrics.snapshot().commits == 0)
        let notReady = try UnifiedSearchFileSettingFixture(ready: false)
        defer { notReady.stop() }
        try notReady.queue()
        notReady.prepare()
        #expect(notReady.controller.fileSettingIssue == "unified.group.backendNotReady")
        #expect(notReady.store.metrics.snapshot().commits == 0)
    }

    @Test func conflictConfirmationUsesActualDifferencesAndExpires() throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(); fixture.prepare()
        try fixture.external([.language(.chinese)])
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil)
        fixture.controller.requestFileSettingConflict(fixture.controller.buffer)
        let old = try #require(fixture.controller.fileSettingConfirmation)
        #expect(old.evidence.differences.first?.baseline == .choice("system"))
        #expect(old.evidence.differences.first?.current == .choice("chinese"))
        try fixture.external([.language(.system)])
        fixture.controller.resolveFileSettingConflict(old, choice: .confirmOverwrite)
        #expect(fixture.controller.fileSettingConfirmation == nil && fixture.store.metrics.snapshot().commits == 0)
        fixture.controller.requestFileSettingConflict(fixture.controller.buffer)
        let current = try #require(fixture.controller.fileSettingConfirmation)
        fixture.controller.resolveFileSettingConflict(current, choice: .confirmOverwrite)
        fixture.submit()
        try fixture.expectSaved(2)
    }

    @Test(arguments: [false, true])
    func displayRevocationDoesNotRenewOldEvents(after: Bool) throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(); fixture.prepare()
        let source = fixture.controller.buffer
        let revoke = { try? fixture.results.session.loseFocus(expecting: source.lease.ownership) }
        if after { fixture.io.onEvent = { _ = revoke() } } else { _ = revoke() }
        fixture.submit()
        #expect(!fixture.controller.operationVisible && fixture.controller.fileSettingReport == nil)
        #expect(fixture.store.metrics.snapshot().commits == (after ? 1 : 0))
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        let count = fixture.store.metrics.snapshot().commits
        if after { fixture.controller.requestOperationSubmit(source) }
        #expect(fixture.store.metrics.snapshot().commits == count)
    }
}
