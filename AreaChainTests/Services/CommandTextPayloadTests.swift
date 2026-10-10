import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandTextPayloadTests {
    @Test func versionOneWithoutCompositionRestoresAndUnknownVersionsFail() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let draft = try f.draft()
        let reference = CommandProtectedReference(payloadID: UUID(), revision: UUID())
        let contents = CommandDraftContents(arguments: draft.arguments, baseline: draft.baseline)
        let payload = try CommandDraftPayload(contents: contents, reference: reference, draft: draft)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(payload.format == 2)
        json["format"] = 1
        let legacy = try JSONDecoder().decode(CommandDraftPayload.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(try legacy.decoded() == contents)
        for format in [0, 3, 99] {
            json["format"] = format
            let invalid = try JSONDecoder().decode(CommandDraftPayload.self, from: JSONSerialization.data(withJSONObject: json))
            #expect(throws: (any Error).self) { try invalid.decoded() }
        }
    }

    @Test func compositionCannotMasqueradeAsConfirmedArgumentOrLegacyState() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let draft = try f.draft()
        let reference = CommandProtectedReference(payloadID: UUID(), revision: UUID())
        var contents = CommandDraftContents(arguments: draft.arguments, baseline: draft.baseline,
            editing: [.init(parameter: "notes", spelling: "拼音-body", selectionLocation: 2, selectionLength: 0,
                composition: .init(text: "拼音", location: 0, replacedText: "synthetic"))])
        let payload = try CommandDraftPayload(contents: contents, reference: reference, draft: draft)
        #expect(try payload.decoded() == contents)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        json["format"] = 1
        let legacy = try JSONDecoder().decode(CommandDraftPayload.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: (any Error).self) { try legacy.decoded() }
        contents.arguments = [.init(parameter: .notes, operation: .replace, value: .longText("拼音-body"))]
        #expect(throws: (any Error).self) { try CommandDraftPayload(contents: contents, reference: reference, draft: draft) }
    }
}
