import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreatePreviewCompositionTests {
    @Test func plainTitleAndDayKeepMinimumContract() throws {
        let fixture = try TaskCreatePreviewFixture("  合成任务  ")
        let host = try fixture.handoff.owned()
        let result = try fixture.preview()
        let original = try CommandTaskCreateInput(#require(host.session.plan.items.first).draft)
        #expect(result.composition.title == original.parsed.cleanTitle)
        #expect(result.composition.day == original.day)
        #expect(result.composition.priority.origins == [.unspecified])
        #expect(result.composition.reminder.origins == [.unspecified])
        #expect(result.composition.tags.final.isEmpty && result.canPrepareExecution && !result.isExecutable)
        #expect(try fixture.handoff.owned() == host)
        #expect(fixture.handoff.coordinator.taskCreations.preparations.isEmpty)
    }

    @Test(arguments: ["p1", "p2", "p3", "p4"])
    func prioritySyntaxAndExplicitValuesRetainBothSources(priority: String) throws {
        let fixture = try TaskCreatePreviewFixture("任务 !" + priority, extra: [
            .init(parameter: .priority, operation: .assign, value: .choice(priority))
        ])
        let value = try fixture.preview()
        #expect(value.canPrepareExecution)
        #expect(value.composition.priority.value == PriorityToken.flags(in: "!" + priority))
        #expect(value.composition.priority.origins == [.titleSyntax, .explicitSet])
    }

    @Test(arguments: [false, true])
    func conflictingPriorityAndReminderNeverPickLastSource(cancel: Bool) throws {
        let fixture = try TaskCreatePreviewFixture("任务 !p2 @09:30", extra: [
            .init(parameter: .priority, operation: cancel ? .clear : .assign, value: cancel ? nil : .choice("p1")),
            .init(parameter: .time, operation: cancel ? .cancelReminder : .setReminder, value: cancel ? nil : .time(600))
        ])
        let result = try fixture.preview()
        #expect(!result.canPrepareExecution)
        #expect(result.issues == [.sourceConflict(.priority), .sourceConflict(.time)])
        #expect(result.composition.priority.syntax == .init(isImportant: true, isUrgent: false))
        #expect(result.composition.reminder.syntax == 570)
        #expect(result.composition.priority.value == nil && result.composition.reminder.value == nil)
        #expect(result.composition.reminder.explicit == (cancel ? .clear : .set(600)))
    }

    @Test func reminderAgreementAndExplicitOnlyValues() throws {
        let agreement = try TaskCreatePreviewFixture("任务 下午3点", extra: [
            .init(parameter: .time, operation: .setReminder, value: .time(900))
        ]).preview()
        #expect(agreement.canPrepareExecution && agreement.composition.reminder.value == 900)
        #expect(agreement.composition.reminder.origins == [.titleSyntax, .explicitSet])
        let explicit = try TaskCreatePreviewFixture(extra: [
            .init(parameter: .priority, operation: .assign, value: .choice("p3")),
            .init(parameter: .time, operation: .setReminder, value: .time(0))
        ]).preview()
        #expect(explicit.canPrepareExecution && explicit.composition.reminder.value == 0)
        #expect(explicit.composition.priority.value == .init(isImportant: false, isUrgent: true))
        #expect(explicit.composition.priority.origins == [.explicitSet])
        let cancelled = try TaskCreatePreviewFixture(extra: [
            .init(parameter: .priority, operation: .clear), .init(parameter: .time, operation: .cancelReminder)
        ]).preview()
        #expect(cancelled.canPrepareExecution && cancelled.composition.reminder.value == nil)
        #expect(cancelled.composition.priority.origins == [.explicitClear])
        #expect(cancelled.composition.reminder.origins == [.explicitClear])
    }

    @Test func parserOwnsEscapingQuotingAndRepeatedSyntax() throws {
        let title = ##"任务 \#literal `#code !p1 @10:00` #"two words" !p1 !p3 @08:00 @09:00"##
        let result = try TaskCreatePreviewFixture(title).preview()
        let parsed = NaturalLanguageParser.parseTaskCapture(title)
        #expect(result.canPrepareExecution && result.composition.title == parsed.cleanTitle)
        #expect(result.composition.reminder.value == 540)
        #expect(result.composition.priority.value == .init(isImportant: false, isUrgent: true))
        #expect(result.composition.tags.final.map(\.target) == [.newName("two words", normalized: "two words")])
    }

    @Test(arguments: ["#普通", "@00:00", "!p1", "!p2", "!p3"])
    func effectiveMetadataCanBePreviewedButNotExecuted(title: String) throws {
        let fixture = try TaskCreatePreviewFixture(title)
        let result = try fixture.preview()
        #expect(result.composition.title.isEmpty && result.canPrepareExecution)
        let draft = try #require(fixture.handoff.state().plan.items.first).draft
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try CommandTaskCreateInput(draft) }
    }

    @Test func erasedMetadataAndP4AreNotContent() throws {
        let p4 = try TaskCreatePreviewFixture("!p4").preview()
        let cleared = try TaskCreatePreviewFixture("#普通", extra: [TaskCreatePreviewFixture.tags(.clear)]).preview()
        #expect(p4.issues == [.emptyEffectiveContent] && !p4.canPrepareExecution)
        #expect(cleared.issues == [.emptyEffectiveContent] && !cleared.canPrepareExecution)
        let explicit = try TaskCreatePreviewFixture("!p4", extra: [
            .init(parameter: .time, operation: .setReminder, value: .time(30))
        ]).preview()
        #expect(explicit.canPrepareExecution && explicit.composition.title.isEmpty)
    }

    @Test(arguments: ["任务 //", "任务 // 正文", "任务 ／／", "任务\n正文", "任务\u{2028}正文", " ", ""])
    func notesNewlinesAndBlankInputsAreRejected(title: String) throws {
        let fixture = try TaskCreatePreviewFixture(title)
        #expect(throws: CommandTaskCreatePreviewIssue.self) { try fixture.preview() }
    }

    @Test(arguments: [CommandFieldOperation.replace, .append, .clear, .unspecified])
    func allNotesOperationsStayClosed(operation: CommandFieldOperation) throws {
        let fixture = try TaskCreatePreviewFixture(extra: [
            .init(parameter: .notes, operation: operation, value: operation.requiresValue ? .longText("正文") : nil)
        ])
        #expect(throws: CommandTaskCreatePreviewIssue.self) { try fixture.preview() }
    }
}
