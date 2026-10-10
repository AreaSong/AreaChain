import Foundation

struct SealedCommandDraft: CustomStringConvertible, CustomDebugStringConvertible {
    #if DEBUG
    /// 只在合成测试中注入封存失败/迟到恢复；不替换加密结果或授予访问权限。
    static var testingBeforeSeal: (() throws -> Void)?
    static var testingAfterOpen: (() -> Void)?
    #endif
    let data: Data
    let vaultID: UUID
    let reference: CommandProtectedReference
    let draftID: UUID
    let commandID: String

    private var context: String {
        "command-draft:1:\(vaultID):\(draftID):\(commandID):\(reference.payloadID):\(reference.revision)"
    }

    static func seal(_ contents: CommandDraftContents, reference: CommandProtectedReference,
                     draft: CommandDraft, vaultID: UUID, keys: VaultKeyAccess) throws -> Self {
        let payload = try CommandTextTiming.measure("payload") {
            try CommandDraftPayload(contents: contents, reference: reference, draft: draft)
        }
        let envelope = Self(data: Data(), vaultID: vaultID, reference: reference, draftID: draft.id,
                            commandID: draft.commandID.rawValue)
        #if DEBUG
        try testingBeforeSeal?()
        #endif
        let encoded = try CommandTextTiming.measure("encode") { try JSONEncoder().encode(payload) }
        let data = try CommandTextTiming.measure("encrypt") { try keys.seal(encoded, vaultID: vaultID, context: envelope.context) }
        return .init(data: data, vaultID: vaultID, reference: reference, draftID: draft.id, commandID: draft.commandID.rawValue)
    }

    func open(keys: VaultKeyAccess) throws -> CommandDraftContents {
        let raw = try keys.open(data, vaultID: vaultID, context: context)
        let payload = try JSONDecoder().decode(CommandDraftPayload.self, from: raw)
        guard [1, 2].contains(payload.format), payload.payloadID == reference.payloadID, payload.revision == reference.revision,
              payload.draftID == draftID, payload.commandID == commandID else { throw CommandDraftProtectionError.invalidPayload }
        let contents = try payload.decoded()
        #if DEBUG
        Self.testingAfterOpen?()
        #endif
        return contents
    }

    var description: String { "SealedCommandDraft(redacted)" }
    var debugDescription: String { description }
}
