import Foundation
import Testing
@testable import AreaChain

struct CommandDraftTests {
    @Test func settingExistingAndCreationRemainDifferent() throws {
        var state = DraftFixture.session()
        DraftFixture.start("setting.language", in: &state)
        #expect(state.active?.targets == CommandDraftTargets.none)
        #expect(state.active?.check().targetIssues.isEmpty == true)
        DraftFixture.edit(.init(parameter: .value, operation: .assign, value: .choice("chinese")), in: &state)
        #expect(state.active?.check().staticallyValid == true)
        #expect(state.active?.check().isExecutable == false)
        #expect(state.active?.check().execution == .unwired)
        let original = DraftFixture.object(.diary)
        let baseline = DraftFixture.baseline(original, .body, .uniform(.longText("Synthetic original")))
        let existing = DraftFixture.draft("diary.body", targets: .init(.single, objects: [original]), baseline: baseline)
        var second = DraftFixture.session()
        DraftFixture.apply(.start(expectedRevision: 0, existing), to: &second)
        DraftFixture.edit(DraftFixture.body("Synthetic original"), in: &second)
        #expect(second.active?.modification == .unchanged)
        DraftFixture.edit(DraftFixture.body("Synthetic edited"), in: &second)
        #expect(second.active?.modification == .modified)
        #expect(second.active?.baseline == baseline)
        var creation = DraftFixture.session()
        DraftFixture.start("diary.create", in: &creation)
        DraftFixture.edit(DraftFixture.body("Synthetic new", operation: .assign), in: &creation)
        #expect(creation.active?.targets.objects.isEmpty == true)
        #expect(creation.active?.check().argumentIssues.contains(.missing(.day)) == true)
        #expect(creation.requiresUnsavedContentHandling)
    }

    @Test func incompleteAndEmptyBodyCanBeRetainedWithoutSubmission() throws {
        var state = DraftFixture.session()
        DraftFixture.start("diary.create", in: &state)
        DraftFixture.edit(DraftFixture.body("", operation: .assign), in: &state)
        #expect(state.active?.check().argumentIssues.contains(.invalidValue(.body)) == true)
        #expect(state.active?.check().parametersComplete == false)
        #expect(state.requiresUnsavedContentHandling)
        DraftFixture.start("setting.language", in: &state)
        let decision = try #require(state.pending)
        DraftFixture.apply(.resolve(decision, .retain), to: &state)
        #expect(state.retained.count == 1)
        #expect(state.retained[0].arguments == [DraftFixture.body("", operation: .assign)])
        #expect(!state.retained[0].check().isExecutable)
        #expect(state.unsavedDrafts == [state.retained[0].stamp])
    }

    @Test func operationSemanticsSurviveEditingAndValidation() {
        let cases: [(String, CommandParameterID, [CommandFieldOperation], CommandValue)] = [
            ("diary.body", .body, [.replace, .append, .clear], .longText("Synthetic body")),
            ("todo.tags", .tags, [.add, .remove, .replaceAll, .clear], .tags([UUID()])),
            ("todo.reminder", .time, [.setReminder, .cancelReminder], .time(600))
        ]
        for (command, parameter, operations, value) in cases {
            var state = DraftFixture.session()
            let type: CommandObjectType = command == "diary.body" ? .diary : .todo
            DraftFixture.start(command, targets: .init(.single, objects: [DraftFixture.object(type)]), in: &state)
            for operation in operations {
                let argument = CommandArgument(parameter: parameter, operation: operation,
                                               value: operation.requiresValue ? value : nil)
                DraftFixture.edit(argument, in: &state)
                #expect(state.active?.arguments == [argument])
                #expect(state.active?.check().argumentIssues.contains(.invalidOperation(parameter)) == false)
                #expect(state.active?.check().isExecutable == false)
            }
            DraftFixture.edit(.init(parameter: parameter, operation: .unspecified), in: &state)
            #expect(state.active?.modification == .unchanged)
            #expect(state.active?.check().parametersComplete == false)
        }
    }

    @Test func identitiesAreTypedDatedAndStablyDeduplicated() {
        let id = UUID()
        let todo = CommandObjectReference(type: .todo, id: id)
        let diary = CommandObjectReference(type: .diary, id: id)
        let day1 = CommandObjectReference(type: .routineOccurrence, id: id, dayKey: "2026-10-01")
        let day2 = CommandObjectReference(type: .routineOccurrence, id: id, dayKey: "2026-10-02")
        let targets = CommandDraftTargets(.allResults, objects: [todo, day1, todo, diary, day2, day1])
        #expect(targets.objects == [todo, day1, diary, day2])
        let draft = DraftFixture.draft("todo.tags", targets: targets)
        #expect(draft.check().targetIssues.contains(.requiresExplicitSelection))
        #expect(draft.targets == targets)
        let invalid = DraftFixture.draft("routine.complete", targets: .init(.single, objects: [
            .init(type: .routineOccurrence, id: id)
        ]))
        let command = CommandCatalog.standard.command(id: .init(rawValue: "tasks.select"))!
        #expect(invalid.targets.issues(for: command).contains(.invalidIdentity))
    }

    @Test func targetDiagnosticsNeverNarrowInvalidSelections() throws {
        let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: "todo.title")))
        let todo = DraftFixture.object(.todo), diary = DraftFixture.object(.diary)
        let targets = CommandDraftTargets(.selected, objects: [todo, diary])
        #expect(targets.issues(for: command).contains(.requiresExplicitSelection))
        #expect(targets.objects == [todo, diary])
        #expect(targets.argument(for: command) == nil)
        #expect(CommandDraftTargets(.selected).issues(for: command).contains(.emptySelection))
        #expect(CommandDraftTargets(.single, objects: [todo, DraftFixture.object(.todo)])
            .issues(for: command).contains(.multipleNotSupported))
        #expect(CommandDraftTargets(.single, objects: [.init(type: .todo, id: UUID(), dayKey: "2026-10-01")])
            .issues(for: command).contains(.invalidIdentity))
        let occurrence = try #require(CommandCatalog.standard.command(id: .init(rawValue: "tasks.select")))
        #expect(CommandDraftTargets(.single, objects: [
            .init(type: .routineOccurrence, id: UUID(), dayKey: "2026-02-30")
        ]).issues(for: occurrence).contains(.invalidIdentity))
        let create = try #require(CommandCatalog.standard.command(id: .init(rawValue: "diary.create")))
        #expect(CommandDraftTargets(.single, objects: [diary]).issues(for: create).contains(.notApplicable))
    }

    @Test func baselinesKeepAbsentMissingAndMixedAndNeverFollowExternalValues() throws {
        let first = DraftFixture.object(.diary), second = DraftFixture.object(.diary)
        let targets = CommandDraftTargets(.selected, objects: [first, second])
        let baseline = CommandDraftBaseline([
            .init(subject: .object(first), parameter: .body): .uniform(.longText("Synthetic A")),
            .init(subject: .object(second), parameter: .body): .uniform(.longText("Synthetic B")),
            .init(subject: .object(first), parameter: .notes): .absent,
            .init(subject: .object(second), parameter: .notes): .absent
        ])
        #expect(baseline.original(.body, targets: targets) == .mixed)
        #expect(baseline.original(.notes, targets: targets) == .absent)
        #expect(baseline.original(.tags, targets: targets) == nil)
        var state = DraftFixture.session()
        DraftFixture.apply(.start(expectedRevision: 0, DraftFixture.draft("diary.body", targets: targets,
                                                                       baseline: baseline)), to: &state)
        DraftFixture.edit(DraftFixture.body("Synthetic local"), in: &state)
        let before = state
        let stamp = try #require(state.active?.stamp)
        #expect(DraftFixture.apply(.externalValuesArrived(stamp), to: &state) == [.externalValuesRequireExplicitReload(stamp)])
        #expect(state == before)
        let fresh = CommandDraftBaseline([
            .init(subject: .object(first), parameter: .body): .uniform(.longText("Synthetic external")),
            .init(subject: .object(second), parameter: .body): .uniform(.longText("Synthetic external"))
        ])
        DraftFixture.apply(.reloadDiscardingChanges(stamp, fresh, [DraftFixture.body("Synthetic external")]), to: &state)
        #expect(state.active?.baseline == fresh)
        #expect(state.active?.modification == .unchanged)
        DraftFixture.edit(DraftFixture.body("Synthetic later"), in: &state)
        let later = state
        #expect(DraftFixture.apply(.reloadDiscardingChanges(stamp, baseline, []), to: &state) == [.rejectedEvent])
        #expect(state == later)
    }
}

enum DraftFixture {
    static func object(_ type: CommandObjectType) -> CommandObjectReference { .init(type: type, id: UUID()) }
    static func baseline(_ object: CommandObjectReference, _ field: CommandParameterID,
                         _ value: CommandOriginalValue) -> CommandDraftBaseline {
        .init([.init(subject: .object(object), parameter: field): value])
    }
    static func body(_ text: String, operation: CommandFieldOperation = .replace) -> CommandArgument {
        .init(parameter: .body, operation: operation, value: .longText(text))
    }
    static func session() -> CommandDraftSession { .init(hostID: "workspace") }
    static func draft(_ command: String, targets: CommandDraftTargets = .none,
                      baseline: CommandDraftBaseline = .init()) -> CommandDraft {
        .init(id: UUID(), hostID: "workspace", commandID: .init(rawValue: command), targets: targets, baseline: baseline)
    }
    @discardableResult static func apply(_ event: CommandDraftEvent, to state: inout CommandDraftSession) -> [CommandDraftIntent] {
        let result = CommandDraftReducer.reduce(state, event)
        state = result.state
        return result.intents
    }
    static func start(_ command: String, targets: CommandDraftTargets = .none, in state: inout CommandDraftSession) {
        apply(.start(expectedRevision: state.revision, draft(command, targets: targets)), to: &state)
    }
    static func edit(_ argument: CommandArgument, in state: inout CommandDraftSession) {
        if let stamp = state.active?.stamp { apply(.edit(stamp, argument), to: &state) }
    }
}
