import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchOperationContractTests {
    @Test func browsingAcceptingAndAliasKeepOneDraft() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let controller = fixture.controller!
        _ = controller.edit(.init(source: controller.buffer, text: "/setting/language", selection: .init(location: 17, length: 0)))
        #expect(controller.operations?.active == nil)
        try fixture.startOperation("setting.language")
        let first = try fixture.draft
        #expect(first.arguments.isEmpty && first.baseline.values.isEmpty)
        let old = controller.buffer
        let parsed = CommandPathParser().parse(.init(text: "/settings/language/chinese"))
        let value = try #require(parsed.arguments.first)
        let accepted = controller.accept(.init(source: old, text: "/settings/language/chinese", selection: .init(location: 26, length: 0),
            acceptance: .init(text: "/settings/language/chinese", cursorLocation: 26, intent: .setArgument(first.commandID, value))))
        #expect(accepted != nil)
        #expect(try fixture.draft.id == first.id && fixture.draft.version > first.version)
        #expect(try fixture.draft.arguments == [value])
        #expect(controller.accept(.init(source: old, text: "old", selection: .init(location: 3, length: 0),
            acceptance: .init(text: "old", cursorLocation: 3, intent: .setArgument(first.commandID, value)))) == nil)
        #expect(controller.operations?.retained.isEmpty == true)
    }

    @Test func numbersAreVersionedSpellingAndNeverInvalidCommandValues() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.limit")
        let controller = fixture.controller!
        for text in ["-", "19", "1000", "1.2", "NaN", ""] {
            try fixture.typeParameter(.value, text: text)
            #expect(try fixture.draft.arguments.first?.value == nil)
            #expect(try !fixture.draft.check().staticallyValid)
        }
        for text in ["20", "999"] {
            try fixture.typeParameter(.value, text: text)
            #expect(try fixture.draft.check().staticallyValid)
        }
        let (parameter, context) = try fixture.parameter(.value)
        let old = controller.parameterBuffer(parameter, draft: try fixture.draft)
        try fixture.typeParameter(.value, text: "25")
        #expect(controller.editParameterText(.init(source: old, text: "30", selection: .init(location: 2, length: 0)), context: context) == nil)
        #expect(try fixture.draft.arguments.first?.value == .number(25))
        #expect(try !fixture.draft.check().isExecutable)
    }

    @Test func metadataCoversAllTypesAndUnsupportedRequirements() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("todo.create")
        try fixture.typeParameter(.title, text: " /setting/language 中文 #原文 ")
        #expect(try fixture.draft.arguments.first?.value == .shortText(" /setting/language 中文 #原文 "))
        try fixture.typeParameter(.day, text: "2028-02-29")
        #expect(try fixture.draft.arguments.last?.value == .day("2028-02-29"))
        try fixture.typeParameter(.day, text: "2027-02-29")
        #expect(try fixture.draft.arguments.last?.value == nil)
        for text in ["00:00", "23:59"] {
            try fixture.typeParameter(.time, text: text)
            #expect(try fixture.draft.arguments.last?.value != nil)
        }
        for text in ["24:00", "23:60"] {
            try fixture.typeParameter(.time, text: text)
            #expect(try fixture.draft.arguments.last?.value == nil)
        }
        let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: "todo.create")))
        let notes = try #require(command.parameters.first { $0.id == .notes })
        #expect(!UnifiedSearchParameterContext.supports(notes, command: command))
        #expect(UnifiedSearchOperationCopy.requirement(notes, command: command) == "unified.operation.longText")
        for command in CommandCatalog.standard.entries where command.interactions.contains(.secureInput) {
            #expect(command.parameters.allSatisfy { !UnifiedSearchParameterContext.supports($0, command: command) })
        }
    }

    @Test func switchRetainRestoreAndOldDecisionCannotDiscardNewEdit() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.limit")
        try fixture.typeParameter(.value, text: "-")
        let firstID = try fixture.draft.id
        try fixture.startOperation("setting.language")
        let decision = try #require(fixture.controller.operations?.pending)
        let source = fixture.controller.buffer
        try fixture.typeParameter(.value, text: "22")
        fixture.controller.resolveOperation(decision, choice: .discard, source: source)
        #expect(try fixture.draft.id == firstID && fixture.draft.arguments.first?.value == .number(22))
        #expect(fixture.controller.operations?.pending == nil)
        try fixture.startOperation("setting.language")
        fixture.controller.resolveOperation(try #require(fixture.controller.operations?.pending), choice: .retain,
            source: fixture.controller.buffer)
        #expect(fixture.controller.operations?.retained.count == 1)
        try fixture.startOperation("clipboard.limit")
        #expect(try fixture.draft.id == firstID && fixture.draft.arguments.first?.value == .number(22))
        let before = try fixture.draft
        _ = fixture.controller.edit(.init(source: fixture.controller.buffer, text: "", selection: .init(location: 0, length: 0)))
        #expect(try fixture.draft == before)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(try fixture.handoff.state().plan.items.isEmpty && fixture.handoff.state().execution == nil)
        #expect(fixture.controller.operationMessage == "unified.operation.submitBlocked")
    }
}
