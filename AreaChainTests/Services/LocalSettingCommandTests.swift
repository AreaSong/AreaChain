import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalSettingCommandTests {
    @Test func fourCommandsUseRealSharedStorageAndNarrowEffects() throws {
        let cases: [(String, CommandValue, LocalPreferenceValue)] = [
            ("setting.language", .choice("chinese"), .language(.chinese)),
            ("setting.appearance", .choice("dark"), .appearance(.dark)),
            ("setting.truncation", .choice("middle"), .quadrantTitleTruncation(.middle)),
            ("setting.captureSource", .boolean(true), .stampCaptureApp(true))
        ]
        for (command, input, target) in cases {
            let fixture = try LocalSettingCommandFixture()
            defer { fixture.cleanup() }
            let itemID = try fixture.queue(command, value: input)
            #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
            let report = try fixture.submit()
            guard case .write(let write) = report.outcome else { Issue.record("缺少实际写入事实"); continue }
            #expect(write.requested == target && write.write == .returned && write.readback == .matches)
            #expect(fixture.io.writes == [target])
            #expect(fixture.prefs.readLocalSetting(target.field).storedValue == target)
            #expect(fixture.io.local.events.map(\.name) == [.localPreferenceDidChange])
            #expect(fixture.io.local.appearances == (target.field == .appearance ? [.dark] : []))
            #expect(try fixture.unit().state == .succeeded && fixture.unit().local == .committed)
            #expect(report.operation.operationID == itemID)
            #expect(try fixture.unit().effects[.notification] == nil && fixture.unit().effects[.calendar] == nil)
        }
    }

    @Test func parserDraftPlanAdapterReceiptChainUsesStableRawValues() throws {
        for text in ["/应用设置/语言/简中", "/setting/appearance/light", "/setting/title-truncation/middle", "/setting/capture-source/true"] {
            let fixture = try LocalSettingCommandFixture()
            defer { fixture.cleanup() }
            let parsed = CommandPathParser().parse(.init(text: text))
            #expect(parsed.state == .command)
            let command = try #require(parsed.command)
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: command.id, arguments: parsed.arguments)
            try fixture.handoff.start(draft)
            try fixture.adapter.prepare(#require(fixture.state().operations.active?.stamp), expecting: fixture.owned().lease)
            let prepared = try #require(fixture.state().operations.active)
            try fixture.handoff.send(.enqueue(prepared.stamp, itemID: UUID(), plan: fixture.state().plan.stamp))
            let report = try fixture.submit()
            #expect(try fixture.state().execution?.snapshot.items[0].draft.id == draft.id)
            #expect(try fixture.unit().receipt == report.receipt)
            #expect(fixture.io.writes.count == 1 && fixture.io.local.events.count == 1)
            #expect(try !command.isExecutable && fixture.state().execution?.isExecutable == false)
        }
    }

    @Test func missingKeysAreReliableDefaultsAndNoChangeHasZeroEffects() throws {
        let cases: [(String, CommandValue)] = [("setting.language", .choice("system")),
            ("setting.appearance", .choice("system")), ("setting.truncation", .choice("tail")),
            ("setting.captureSource", .boolean(false))]
        for (command, input) in cases {
            let fixture = try LocalSettingCommandFixture()
            defer { fixture.cleanup() }
            try fixture.queue(command, value: input)
            let baseline = try #require(fixture.state().plan.items[0].draft.baseline.preference)
            #expect(baseline.raw == .missing && baseline.memory == input && baseline.stored == input)
            let report = try fixture.submit()
            #expect(report.outcome == .noChange && report.receipt.result == .noChange)
            #expect(try fixture.unit().local == .notSubmitted && fixture.unit().state == .succeeded)
            #expect(try fixture.unit().effects.isEmpty && fixture.unit().preferenceWrite == nil)
            #expect(fixture.io.writes.isEmpty && fixture.io.local.appearances.isEmpty && fixture.io.local.events.isEmpty)
            #expect(try fixture.state().execution?.retryAssessment(report.receipt.attempt, assurance: .safeLocalReplay) == .notRetryable)
            #expect(throws: LocalSettingCommandIssue.notRetryable) {
                try fixture.adapter.returnUnsubmittedToPlan(report.receipt.attempt, expecting: fixture.owned().lease)
            }
        }
    }

    @Test func storedTargetNoChangeAndOldBindingStillWritesSameValue() throws {
        let io = try PreferenceCommandIO()
        io.local.defaults.set("dark", forKey: AppPreferences.appearanceKey)
        let fixture = try LocalSettingCommandFixture(io: io)
        defer { fixture.cleanup() }
        try fixture.queue("setting.appearance", value: .choice("dark"))
        #expect(try fixture.submit().outcome == .noChange)
        #expect(io.writes.isEmpty && io.local.events.isEmpty && io.local.appearances.isEmpty)
        fixture.prefs.appearance = .dark
        #expect(io.writes == [.appearance(.dark)] && io.local.appearances == [.dark])
        #expect(io.local.events.map(\.name) == [.localPreferenceDidChange])
    }

    @Test func strictMappingRejectsEveryMalformedFormWithoutWriting() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let invalid: [[CommandArgument]] = [[],
            [.init(parameter: .value, operation: .assign, value: nil)],
            [.init(parameter: .value, operation: .assign, value: .choice("unknown"))],
            [.init(parameter: .value, operation: .clear, value: nil)],
            [.init(parameter: .value, operation: .unspecified, value: .choice("english"))],
            [.init(parameter: .value, operation: .assign, value: .shortText("english"))],
            [PlanFixture.argument(.value, .choice("english")), PlanFixture.argument(.value, .choice("chinese"))],
            [PlanFixture.argument(.value, .choice("english")), PlanFixture.argument(.enabled, .boolean(true))]
        ]
        for arguments in invalid {
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: "setting.language"), arguments: arguments)
            #expect(throws: LocalSettingCommandIssue.invalidArguments) { try LocalSettingCommandMapping.value(for: draft) }
        }
        for value in [CommandValue.choice("true"), .number(1), .shortText("true")] {
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "setting.captureSource"),
                arguments: [PlanFixture.argument(.enabled, value)])
            #expect(throws: LocalSettingCommandIssue.invalidArguments) { try LocalSettingCommandMapping.value(for: draft) }
        }
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
    }

    @Test func missingAssemblySyntheticBaselineAndTargetsCannotExecute() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue(realBaseline: false)
        let closed = LocalSettingCommandAdapter(coordinator: fixture.handoff.coordinator)
        #expect(throws: LocalSettingCommandIssue.unwired) { try closed.submit(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease) }
        #expect(throws: LocalSettingCommandIssue.missingBaseline) { try fixture.submit() }
        let item = try #require(fixture.state().plan.items.first)
        let targeted = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: item.draft.commandID,
            targets: .init(.single, objects: [.init(type: .todo, id: UUID())]), arguments: item.draft.arguments)
        #expect(throws: LocalSettingCommandIssue.invalidTargets) { try LocalSettingCommandMapping.value(for: targeted) }
        #expect(try fixture.io.writes.isEmpty && fixture.state().plan.items.count == 1)
        let request = try fixture.request()
        #expect(try fixture.adapter.execute(request).outcome == .rejected(.missingBaseline))
        #expect(fixture.io.writes.isEmpty)
    }
}
