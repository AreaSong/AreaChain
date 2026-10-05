import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalSettingCommandBoundaryTests {
    @Test func unsupportedProtectedUnknownAndExtraArgumentsAreRejectedAtPreparation() throws {
        let cases: [(String, [CommandArgument])] = [
            ("setting.login", [PlanFixture.argument(.enabled, .boolean(true))]),
            ("setting.language", [PlanFixture.argument(.value, .choice("english")), PlanFixture.argument(.enabled, .boolean(true))]),
            ("setting.appearance", [PlanFixture.argument(.value, .choice("unknown"))]),
            ("setting.truncation", [PlanFixture.argument(.value, .choice("system"))]),
            ("setting.captureSource", [PlanFixture.argument(.enabled, .choice("true"))])
        ]
        for (command, arguments) in cases {
            let fixture = try LocalSettingCommandFixture()
            defer { fixture.cleanup() }
            try fixture.handoff.start(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: command), arguments: arguments))
            #expect(throws: LocalSettingCommandIssue.self) {
                try fixture.adapter.prepare(#require(fixture.state().operations.active?.stamp), expecting: fixture.owned().lease)
            }
            #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        }
        for protection in [CommandProtectionRequirement.unknown, .required] {
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "setting.language"),
                arguments: [PlanFixture.argument(.value, .choice("english"))], protectionRequirement: protection)
            #expect(throws: LocalSettingCommandIssue.protectedContent) { try LocalSettingCommandMapping.value(for: draft) }
        }
    }

    @Test func evidenceCannotBeCopiedToAnotherDraftOrFabricatedFromUIValues() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let original = try fixture.state().plan.items[0].draft
        let other = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: original.commandID,
            baseline: original.baseline, arguments: original.arguments)
        try fixture.handoff.start(other)
        #expect(throws: LocalSettingCommandIssue.untrustedBaseline) {
            try fixture.adapter.prepare(#require(fixture.state().operations.active?.stamp), expecting: fixture.owned().lease)
        }
        #expect(fixture.io.writes.isEmpty)
        // 另一适配实例没有该次读取的签发登记，不能只凭结构相同取得真实执行资格。
        let replacement = LocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator, preferences: fixture.prefs)
        #expect(throws: LocalSettingCommandIssue.untrustedBaseline) {
            try replacement.prepare(original.stamp, expecting: fixture.owned().lease)
        }
    }

    @Test func unrelatedFieldWriteDoesNotBlockActualExecution() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        fixture.prefs.appearance = .dark
        fixture.io.resetCounts()
        _ = try fixture.submit()
        #expect(fixture.io.writes == [.language(.english)] && fixture.prefs.appearance == .dark)
        #expect(fixture.io.local.appearances.isEmpty && fixture.io.local.events.count == 1)
    }

    @Test func fabricatedForeignEvidenceIsRejectedWithoutStrandingInvocation() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let id = UUID(), command = CommandID(rawValue: "setting.language")
        let evidence = CommandPreferenceBaseline(captureID: UUID(), draftID: id, capturedVersion: 0, commandID: command,
            instanceID: UUID(), storageID: ObjectIdentifier(fixture.io.local.defaults), revision: 0,
            raw: .missing, memory: .choice("system"), stored: .choice("system"))
        try fixture.handoff.start(.init(id: id, hostID: HandoffFixture.source, commandID: command,
            baseline: .init(preference: evidence), arguments: [PlanFixture.argument(.value, .choice("english"))]))
        try fixture.handoff.send(.enqueue(#require(fixture.state().operations.active?.stamp), itemID: UUID(), plan: fixture.state().plan.stamp))
        let request = try fixture.request()
        #expect(try fixture.adapter.execute(request).outcome == .rejected(.untrustedBaseline))
        #expect(try fixture.unit().state == .failed && fixture.unit().local == .notSubmitted)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
    }

    @Test func systemTailAndFalseAreAppliedWithoutFallbackCoercion() throws {
        let cases: [(String, String, Any, CommandValue, LocalPreferenceValue)] = [
            ("setting.language", AppPreferences.languageKey, "english", .choice("system"), .language(.system)),
            ("setting.appearance", AppPreferences.appearanceKey, "dark", .choice("system"), .appearance(.system)),
            ("setting.truncation", AppPreferences.quadrantTitleTruncationKey, "middle", .choice("tail"), .quadrantTitleTruncation(.tail)),
            ("setting.captureSource", AppPreferences.stampCaptureAppKey, true, .boolean(false), .stampCaptureApp(false))
        ]
        for (command, key, initial, input, expected) in cases {
            let io = try PreferenceCommandIO()
            io.local.defaults.set(initial, forKey: key)
            let fixture = try LocalSettingCommandFixture(io: io)
            defer { fixture.cleanup() }
            try fixture.queue(command, value: input)
            _ = try fixture.submit()
            #expect(io.writes == [expected] && fixture.prefs.readLocalSetting(expected.field).storedValue == expected)
        }
    }

    @Test func safeUnsubmittedRetryAdvancesAttemptAndRejectsOldCallback() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let first = try fixture.request()
        fixture.io.resetCounts()
        fixture.io.onRead = { _, count in if count == 2 { throw PreferenceCommandIO.Failure.injected } }
        _ = try fixture.adapter.execute(first)
        #expect(fixture.io.writes.isEmpty)
        fixture.io.onRead = nil
        try fixture.handoff.send(.retry(first.attempt, .safeLocalReplay))
        let next = try fixture.handoff.begin()
        #expect(next.number == first.attempt.number + 1)
        #expect(throws: (any Error).self) { try fixture.adapter.execute(first) }
        let staleAttempt = try LocalSettingCommandRequest(lease: fixture.owned().lease, operation: first.operation, attempt: first.attempt)
        #expect(throws: LocalSettingCommandIssue.stale) { try fixture.adapter.execute(staleAttempt) }
        let request = try LocalSettingCommandRequest(lease: fixture.owned().lease, operation: first.operation, attempt: next)
        _ = try fixture.adapter.execute(request)
        #expect(fixture.io.writes == [.language(.english)])
    }

    @Test func invalidBooleanStorageCannotBeCoercedIntoNoChange() throws {
        for raw in [1, "true"] as [Any] {
            let io = try PreferenceCommandIO()
            io.local.defaults.set(raw, forKey: AppPreferences.stampCaptureAppKey)
            let fixture = try LocalSettingCommandFixture(io: io)
            defer { fixture.cleanup() }
            #expect(fixture.prefs.stampCaptureApp)
            #expect(throws: LocalSettingCommandIssue.self) {
                try fixture.queue("setting.captureSource", value: .boolean(true))
            }
            #expect(io.writes.isEmpty && io.local.events.isEmpty)
        }
    }

    @Test func mixedPlanAndDistinctRealBaselinesCannotBeSilentlyReducedToOne() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let first = try fixture.queue()
        let second = try fixture.queue(value: .choice("chinese"))
        let items = try fixture.state().plan.items
        #expect(throws: CommandPlanError.mergeConflict(.baseline)) {
            try fixture.handoff.plan(.merge(earlier: items[0].stamp, later: items[1].stamp))
        }
        #expect(throws: LocalSettingCommandIssue.multipleOperations) { try fixture.submit() }
        #expect(try fixture.state().plan.items.map(\.id) == [first, second])
        _ = try fixture.handoff.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source))
        #expect(throws: LocalSettingCommandIssue.multipleOperations) { try fixture.submit() }
        #expect(try fixture.state().plan.items.count == 3 && fixture.io.writes.isEmpty)
    }

    @Test func commandEventsReachOnlyPresentationRoutes() async throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        var diaryChrome = 0, diaryBody = 0, calendar = 0
        let observers = [
            PreferenceObservation(source: fixture.prefs.localPreferenceSource, consumer: .diaryWindow,
                center: fixture.io.local.center, presentation: { diaryChrome += 1 }, legacy: { diaryBody += 1 }),
            PreferenceObservation(source: fixture.prefs.localPreferenceSource, consumer: .calendar,
                center: fixture.io.local.center, presentation: { calendar += 1 }, legacy: { calendar += 1 })
        ]
        defer { observers.forEach { $0.cancel() } }
        let cases: [(String, CommandValue)] = [("setting.language", .choice("english")),
            ("setting.appearance", .choice("dark")), ("setting.truncation", .choice("middle")),
            ("setting.captureSource", .boolean(true))]
        for (command, value) in cases {
            try fixture.queue(command, value: value)
            let report = try fixture.submit()
            try fixture.handoff.send(.releaseExecution(report.operation.execution))
        }
        for _ in 0..<20 { await Task.yield() }
        #expect(diaryChrome == 1 && diaryBody == 0 && calendar == 0)
        #expect(fixture.io.writes.count == 4 && fixture.io.local.events.count == 4)
        #expect(fixture.io.local.events.allSatisfy { $0.name == .localPreferenceDidChange })
    }
}
