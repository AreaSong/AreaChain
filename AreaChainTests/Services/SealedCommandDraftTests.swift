import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SealedCommandDraftTests {
    @Test func contextRejectsWrongVaultObjectRevisionReplacementAndDamage() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let draft = try f.draft()
        let reference = CommandProtectedReference(payloadID: UUID(), revision: UUID())
        let id = try #require(f.vault.configuration?.vaultID)
        let contents = CommandDraftContents(arguments: draft.arguments, baseline: draft.baseline)
        let sealed = try SealedCommandDraft.seal(contents, reference: reference, draft: draft, vaultID: id, keys: f.vault.keys)
        let another = try SealedCommandDraft.seal(contents, reference: .init(payloadID: UUID(), revision: UUID()),
                                                draft: draft, vaultID: id, keys: f.vault.keys)
        let variants: [SealedCommandDraft] = [
            .init(data: sealed.data, vaultID: UUID(), reference: reference, draftID: draft.id, commandID: draft.commandID.rawValue),
            .init(data: sealed.data, vaultID: id, reference: reference, draftID: UUID(), commandID: draft.commandID.rawValue),
            .init(data: sealed.data, vaultID: id, reference: .init(payloadID: reference.payloadID, revision: UUID()),
                  draftID: draft.id, commandID: draft.commandID.rawValue),
            .init(data: another.data, vaultID: id, reference: reference, draftID: draft.id, commandID: draft.commandID.rawValue),
            .init(data: Data(sealed.data.dropLast()), vaultID: id, reference: reference, draftID: draft.id, commandID: draft.commandID.rawValue)
        ]
        for variant in variants { #expect(throws: (any Error).self) { try variant.open(keys: f.vault.keys) } }
        #expect(try sealed.open(keys: f.vault.keys) == contents)
        #expect(!String(reflecting: sealed).contains("synthetic-body"))
    }

    @Test func authenticatedUnsupportedFormatAndInvalidSelectionAreRejected() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let draft = try f.draft()
        let reference = CommandProtectedReference(payloadID: UUID(), revision: UUID())
        let id = try #require(f.vault.configuration?.vaultID)
        let contents = CommandDraftContents(arguments: draft.arguments, baseline: draft.baseline)
        let payload = try CommandDraftPayload(contents: contents, reference: reference, draft: draft)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        json["format"] = 99
        let context = "command-draft:1:\(id):\(draft.id):\(draft.commandID.rawValue):\(reference.payloadID):\(reference.revision)"
        let data = try f.vault.keys.seal(JSONSerialization.data(withJSONObject: json), vaultID: id, context: context)
        let envelope = SealedCommandDraft(data: data, vaultID: id, reference: reference,
                                          draftID: draft.id, commandID: draft.commandID.rawValue)
        #expect(throws: CommandDraftProtectionError.invalidPayload) { try envelope.open(keys: f.vault.keys) }
        var invalid = contents
        invalid.editing = [.init(parameter: "notes", spelling: "a", selectionLocation: 2, selectionLength: 0)]
        #expect(throws: CommandDraftProtectionError.invalidPayload) {
            try SealedCommandDraft.seal(invalid, reference: reference, draft: draft, vaultID: id, keys: f.vault.keys)
        }
    }

    @Test func nativeCapabilitiesCannotEnterPayloadAndDiaryFormatStillRestores() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let draft = try f.draft()
        let id = try #require(f.vault.configuration?.vaultID)
        let contents = CommandDraftContents(arguments: [.init(parameter: .file, operation: .assign, value: .nativeSelection(UUID()))],
                                            baseline: .init())
        #expect(throws: CommandDraftProtectionError.unsupported) {
            try SealedCommandDraft.seal(contents, reference: .init(payloadID: UUID(), revision: UUID()),
                                       draft: draft, vaultID: id, keys: f.vault.keys)
        }
        let old = try SealedDiaryDraft.seal(text: "old-synthetic", baseline: "old-baseline", id: UUID(), vault: f.vault)
        f.vault.lock()
        try f.unlock()
        #expect(try old.open(vault: f.vault) == DiaryDraftText(text: "old-synthetic", baseline: "old-baseline"))
    }

    @Test func checkpointCostByPayloadSize() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let draft = try f.draft()
        let id = try #require(f.vault.configuration?.vaultID)
        for count in [1_024, 65_536, 1_048_576] {
            let text = String(repeating: "中a🙂", count: count / 8)
            let contents = CommandDraftContents(arguments: [.init(parameter: .notes, operation: .replace, value: .longText(text))],
                baseline: .init([.init(subject: .ambient, parameter: .notes): .uniform(.longText(text))]))
            var milliseconds: [Double] = []
            var encryptedBytes = 0
            for _ in 0..<6 {
                let start = ProcessInfo.processInfo.systemUptime
                let sealed = try SealedCommandDraft.seal(contents, reference: .init(payloadID: UUID(), revision: UUID()),
                    draft: draft, vaultID: id, keys: f.vault.keys)
                milliseconds.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
                encryptedBytes = sealed.data.count
                #expect(try sealed.open(keys: f.vault.keys) == contents)
            }
            let warm = milliseconds.dropFirst()
            let sample = "C2A_CHECKPOINT textUTF8=\(text.utf8.count) baselineUTF8=\(text.utf8.count) ciphertext=\(encryptedBytes) firstMS=\(milliseconds[0]) warmMeanMS=\(warm.reduce(0, +) / Double(warm.count)) warmMaxMS=\(warm.max() ?? 0) n=6 mainActor=true"
            print(sample)
            #if compiler(>=6.2)
            Attachment.record(sample, named: "command-checkpoint-\(count).txt")
            #endif
        }
    }
}
