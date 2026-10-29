import Foundation
import Testing
@testable import AreaChain

struct CommandParameterTests {
    private let catalog = CommandCatalog.standard

    @Test func requiredOptionalAndDefaultParametersHaveDistinctMeaning() throws {
        let create = try #require(catalog.command(path: "/tasks/add"))
        let args: [CommandArgument] = [
            .init(parameter: .title, operation: .assign, value: .shortText("Synthetic task")),
            .init(parameter: .day, operation: .assign, value: .day("2026-10-01"))
        ]
        #expect(CommandArgumentValidation.issues(for: args, command: create).isEmpty)
        #expect(CommandArgumentValidation.issues(for: [], command: create).contains(.missing(.title)))
        let copy = try #require(catalog.command(path: "/tasks/copy"))
        #expect(copy.parameters.first { $0.id == .section }?.defaultValue == .choice("record"))
        #expect(!CommandArgumentValidation.issues(for: [], command: copy).contains(.missing(.section)))
        let language = try #require(catalog.command(path: "/setting/language"))
        #expect(CommandArgumentValidation.issues(for: [], command: language) == [.missing(.value)])
    }

    @Test func unspecifiedAssignmentClearAndMixedRemainDistinct() throws {
        let create = try #require(catalog.command(path: "/tasks/add"))
        let base: [CommandArgument] = [
            .init(parameter: .title, operation: .assign, value: .shortText("Synthetic")),
            .init(parameter: .day, operation: .assign, value: .day("2026-10-01"))
        ]
        #expect(CommandArgumentValidation.issues(for: base + [.init(parameter: .notes, operation: .unspecified)], command: create).isEmpty)
        #expect(CommandArgumentValidation.issues(for: base + [.init(parameter: .notes, operation: .clear)], command: create).isEmpty)
        #expect(CommandArgumentValidation.issues(for: base + [
            .init(parameter: .notes, operation: .unspecified, value: .longText("ignored"))
        ], command: create).contains(.unexpectedValue(.notes)))
        #expect(CommandOriginalValue.mixed != .absent)
        #expect(CommandOriginalValue.mixed != .uniform(.longText("")))
    }

    @Test func bodyOperationsCannotBypassNonemptyRule() throws {
        let command = try #require(catalog.command(path: "/diaries/body"))
        let targets = CommandArgument(parameter: .target, operation: .assign,
                                      value: .objects([.init(type: .diary, id: UUID())]))
        for operation in [CommandFieldOperation.replace, .append] {
            let args = [targets, .init(parameter: .body, operation: operation, value: .longText("Line one\n第二行"))]
            #expect(CommandArgumentValidation.issues(for: args, command: command).isEmpty)
        }
        #expect(CommandArgumentValidation.issues(for: [targets, .init(parameter: .body, operation: .clear)], command: command)
            .contains(.invalidValue(.body)))
        #expect(CommandArgumentValidation.issues(for: [targets,
            .init(parameter: .body, operation: .replace, value: .longText(" \n"))
        ], command: command).contains(.invalidValue(.body)))
        #expect(CommandArgumentValidation.issues(for: [targets,
            .init(parameter: .body, operation: .add, value: .longText("text"))
        ], command: command).contains(.invalidOperation(.body)))
    }

    @Test func tagOperationsAndReminderCancellationRequireCorrectOperands() throws {
        let tags = try #require(catalog.command(path: "/tasks/tags"))
        let target = CommandArgument(parameter: .target, operation: .assign, value: .objects([.init(type: .todo, id: UUID())]))
        for operation in [CommandFieldOperation.add, .remove, .replaceAll] {
            #expect(CommandArgumentValidation.issues(for: [target,
                .init(parameter: .tags, operation: operation, value: .tags([UUID()]))
            ], command: tags).isEmpty)
        }
        #expect(CommandArgumentValidation.issues(for: [target, .init(parameter: .tags, operation: .clear)], command: tags).isEmpty)
        let reminder = try #require(catalog.command(path: "/tasks/reminder"))
        #expect(CommandArgumentValidation.issues(for: [target, .init(parameter: .time, operation: .cancelReminder)], command: reminder).isEmpty)
        #expect(CommandArgumentValidation.issues(for: [target,
            .init(parameter: .time, operation: .cancelReminder, value: .time(600))
        ], command: reminder).contains(.unexpectedValue(.time)))
        #expect(CommandArgumentValidation.issues(for: [target,
            .init(parameter: .time, operation: .assign, value: .time(600))
        ], command: reminder).contains(.invalidOperation(.time)))
    }

    @Test func datesClockAndWeekdayBoundariesReuseExistingRules() {
        for valid in ["2024-02-29", "2026-10-01", "2000-02-29"] {
            #expect(CommandArgumentValidation.accepts(.day(valid), type: .day))
        }
        for invalid in ["2025-02-29", "2026-02-30", "2026-13-01", "2026-1-01", "tomorrow", "2026-10-01T00:00:00Z"] {
            #expect(!CommandArgumentValidation.accepts(.day(invalid), type: .day))
        }
        for value in [-1, 0, 1439, 1440] {
            #expect(CommandArgumentValidation.accepts(.time(value), type: .time) == (RemindMinutes.clamped(value) != nil))
        }
        #expect(!CommandArgumentValidation.accepts(.weekdays(0), type: .weekdays))
        #expect(!CommandArgumentValidation.accepts(.weekdays(128), type: .weekdays))
        #expect(CommandArgumentValidation.accepts(.weekdays(WeekdayMask.workdays), type: .weekdays))
    }

    @Test func enumBooleanNumberTextAndNativeSelectionTypesAreNotInterchangeable() {
        let boolean = CommandParameterType.boolean
        #expect(!CommandArgumentValidation.accepts(.shortText("true"), type: boolean))
        let number = CommandParameterType.number(20...999, integer: true)
        for invalid in [19.0, 1000.0, 20.5, .nan, .infinity] {
            #expect(!CommandArgumentValidation.accepts(.number(invalid), type: number))
        }
        #expect(CommandArgumentValidation.accepts(.number(20), type: number))
        #expect(CommandArgumentValidation.accepts(.number(999), type: number))
        #expect(!CommandArgumentValidation.accepts(.number(Double(Int.max)), type: .number(0...Double(Int.max), integer: true)))
        #expect(!CommandArgumentValidation.accepts(.shortText("line\nbreak"), type: .shortText))
        #expect(!CommandArgumentValidation.accepts(.longText("title"), type: .shortText))
        #expect(!CommandArgumentValidation.accepts(.shortText("/tmp/example.png"), type: .nativeFile(.image)))
        #expect(CommandArgumentValidation.accepts(.nativeSelection(UUID()), type: .nativeFile(.image)))
        #expect(!CommandArgumentValidation.accepts(.choice("中文"), type: .choice([CommandChoice(value: "chinese")])))
    }

    @Test func occurrenceIdentityRequiresDateWhileDefinitionMustNotHaveOne() {
        let id = UUID()
        let occurrence = CommandObjectReference(type: .routineOccurrence, id: id, dayKey: "2026-10-01")
        #expect(CommandArgumentValidation.accepts(.object(occurrence), type: .object([.routineOccurrence])))
        #expect(!CommandArgumentValidation.accepts(.object(.init(type: .routineOccurrence, id: id)), type: .object([.routineOccurrence])))
        #expect(!CommandArgumentValidation.accepts(.object(.init(type: .routine, id: id, dayKey: "2026-10-01")), type: .object([.routine])))
        #expect(!CommandArgumentValidation.accepts(.object(occurrence), type: .object([.routine])))
        #expect(!CommandArgumentValidation.accepts(.objects([]), type: .objects([.todo])))
        #expect(!CommandArgumentValidation.accepts(.objects([occurrence, occurrence]), type: .objects([.routineOccurrence])))
        let next = CommandObjectReference(type: .routineOccurrence, id: id, dayKey: "2026-10-02")
        #expect(CommandArgumentValidation.accepts(.objects([occurrence, next]), type: .objects([.routineOccurrence])))
    }

    @Test func illegalParameterDefinitionsAndDuplicateArgumentsAreRejected() throws {
        var parameter = CommandCatalogBuilder.p(.enabled, .boolean)
        parameter.operations = [.append]
        parameter.defaultOperation = .append
        #expect(!CommandCatalogValidation.validDefinition(parameter))
        parameter = CommandCatalogBuilder.choice(.value, "system chinese english").defaulting(to: .choice("fr"))
        #expect(!CommandCatalogValidation.validDefinition(parameter))
        parameter = CommandCatalogBuilder.p(.notes, .longText).defaulting(to: .longText("Synthetic"))
            .editing([.clear], default: .clear)
        #expect(!CommandCatalogValidation.validDefinition(parameter))
        let command = try #require(catalog.command(path: "/setting/language"))
        let value = CommandArgument(parameter: .value, operation: .assign, value: .choice("chinese"))
        #expect(CommandArgumentValidation.issues(for: [value, value], command: command).contains(.duplicate(.value)))
        #expect(CommandArgumentValidation.issues(for: [.init(parameter: .time, operation: .assign, value: .time(0))], command: command)
            .contains(.unknown(.time)))
    }

    @Test func mergeCannotTargetItsOwnSourceAndSingleSelectionCannotContainMany() throws {
        let reference = CommandObjectReference(type: .tag, id: UUID())
        let merge = try #require(catalog.command(path: "/tags/merge"))
        let issues = CommandArgumentValidation.issues(for: [
            .init(parameter: .target, operation: .assign, value: .objects([reference])),
            .init(parameter: .destination, operation: .assign, value: .object(reference))
        ], command: merge)
        #expect(issues.contains(.incompatibleTargets))
        // tag.merge 已按用户决定解决（目录已声明），不再报 unavailable；目标与来源相同仍不兼容。
        #expect(!issues.contains(.unavailable))
        let selection = try #require(catalog.command(path: "/gantt/select"))
        #expect(CommandArgumentValidation.issues(for: [
            .init(parameter: .target, operation: .assign, value: .objects([.init(type: .todo, id: UUID()), .init(type: .todo, id: UUID())])),
            .init(parameter: .mode, operation: .assign, value: .choice("single"))
        ], command: selection).contains(.incompatibleTargets))
    }

    @Test func credentialsHaveNoParameterOrSerializationChannel() throws {
        for name in ["password", "masterPassword", "key", "secret", "credential"] {
            #expect(CommandParameterID(rawValue: name) == nil)
        }
        let secure = try #require(catalog.command(path: "/privacy/set-password"))
        #expect(secure.parameters.isEmpty)
        #expect(secure.interactions.contains(.secureInput))
        #expect(catalog.command(path: "/privacy/unlock/credential") == nil)
        let value: Any = CommandValue.shortText("synthetic ordinary text")
        #expect(!(value is any Encodable))
        #expect(!(secure as Any is any Encodable))
    }

    @Test func existingChoiceCatalogsAndSeparateStatusDimensionsStayCompatible() throws {
        let status = try #require(catalog.command(path: "/tasks/status"))
        #expect(status.parameters.map(\.id) == [.status, .routineStatus])
        #expect(CommandArgumentValidation.issues(for: [
            .init(parameter: .status, operation: .assign, value: .choice("disabled"))
        ], command: status).contains(.invalidValue(.status)))
        let color = try #require(catalog.command(path: "/tags/color")?.parameters.first { $0.id == .color })
        #expect(color.type == .choice(TagColorToken.allCases.map { CommandChoice(value: $0.rawValue) }))
        let language = try #require(catalog.command(path: "/setting/language")?.parameters.first)
        #expect(language.type == .choice(AppLanguage.allCases.map { CommandChoice(value: $0.rawValue) }))
        #expect(CommandFileKind.image.imageFormats == ["png", "jpeg", "heic", "gif", "tiff", "webp"])
        #expect(!CommandFileKind.image.allowsMultipleSelection)
    }

    @Test func longTextLimitCountsConfirmedUTF8BytesAtTheBoundary() {
        let limit = CommandLongTextLimit.maxUTF8Bytes
        #expect(limit == 65_536)
        #expect(CommandLongTextLimit.allows(String(repeating: "a", count: limit)))
        #expect(!CommandLongTextLimit.allows(String(repeating: "a", count: limit + 1)))
        // 中文 3 字节、emoji 4 字节、组合重音 e+U+0301 共 3 字节：按 UTF-8 字节而非字符或 UTF-16 计。
        let chinese = String(repeating: "中", count: limit / 3)
        #expect(chinese.utf8.count == limit - 1 && CommandLongTextLimit.allows(chinese + "a"))
        #expect(!CommandLongTextLimit.allows(chinese + "中"))
        let emoji = String(repeating: "🙂", count: limit / 4)
        #expect(CommandLongTextLimit.allows(emoji) && !CommandLongTextLimit.allows(emoji + "a"))
        let combining = String(repeating: "e\u{301}", count: limit / 3) + "a"
        #expect(combining.utf8.count == limit && CommandLongTextLimit.allows(combining))
        #expect(!CommandLongTextLimit.allows(combining + "\u{301}"))
        // 组合缓冲不计入：已确认正文满额时，正在组词的拼写仍不超限。
        let confirmed = String(repeating: "a", count: limit)
        let composing = CommandDraftEditingState(parameter: "notes", spelling: confirmed + "zhong",
            selectionLocation: limit + 5, selectionLength: 0,
            composition: .init(text: "zhong", location: limit, replacedText: ""))
        #expect(CommandLongTextLimit.allows(composing.confirmedText))
        #expect(!CommandLongTextLimit.allows(composing.confirmingComposition().confirmedText))
    }

    @Test func overLimitLongTextIsDistinctFromInvalidValue() throws {
        let body = try #require(catalog.command(path: "/diaries/body"))
        let target = CommandArgument(parameter: .target, operation: .assign, value: .objects([.init(type: .diary, id: UUID())]))
        let limit = CommandLongTextLimit.maxUTF8Bytes
        func issues(_ text: String) -> [CommandArgumentIssue] {
            CommandArgumentValidation.issues(for: [target, .init(parameter: .body, operation: .replace, value: .longText(text))], command: body)
        }
        #expect(issues(String(repeating: "中", count: limit / 3)).isEmpty)
        #expect(issues(String(repeating: "中", count: limit / 3 + 1)) == [.tooLong(.body)])
        #expect(issues(" \n") == [.invalidValue(.body)])
        #expect(CommandArgumentIssue.tooLong(.body) != .invalidValue(.body))
        #expect(!CommandArgumentValidation.accepts(.longText(String(repeating: "a", count: limit + 1)), type: .longText))
        #expect(CommandArgumentValidation.accepts(.longText(String(repeating: "a", count: limit)), type: .longText))
        let notes = try #require(catalog.command(path: "/tasks/notes"))
        let todo = CommandArgument(parameter: .target, operation: .assign, value: .objects([.init(type: .todo, id: UUID())]))
        #expect(CommandArgumentValidation.issues(for: [todo, .init(parameter: .notes, operation: .append,
            value: .longText(String(repeating: "🙂", count: limit / 4 + 1)))], command: notes) == [.tooLong(.notes)])
        // 上限只约束 longText 参数，短文本仍按原规则判定。
        #expect(CommandArgumentValidation.accepts(.shortText(String(repeating: "a", count: limit + 1)), type: .shortText))
    }
}
