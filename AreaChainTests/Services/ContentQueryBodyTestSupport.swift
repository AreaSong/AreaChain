import Foundation
import Testing
@testable import AreaChain

extension SearchReadFixture {
    func prepareBodies() throws -> ContentQueryReadHandle {
        try session.prepareBodies(observation: RoutineContentQueryFixture.observation())
    }

    func publishBodies(_ source: String = "/diaries") async throws -> ContentQueryReadPublication {
        try handoff.send(.query(.setInput(source)))
        let handle = try prepareBodies()
        try session.evaluate(handle)
        try await session.publish(handle)
        return try session.presentation()
    }

    func protectedDiary(_ text: String) throws -> DiaryEntry {
        let entry = data.diary()
        let config = try #require(vault.configuration)
        entry.encryptedText = try vault.keys.seal(Data(text.utf8), vaultID: config.vaultID,
                                                  context: "diary:\(entry.id.uuidString)")
        entry.privacyVaultID = config.vaultID
        entry.isPrivate = true
        entry.text = "SYNTHETIC_RAW_FALLBACK_FORBIDDEN"
        return entry
    }

    static func diaryResponse(_ publication: ContentQueryReadPublication) throws -> DiaryQueryResponse {
        try #require(publication.response.readings.compactMap {
            if case .diary(let value) = $0 { return value }; return nil
        }.first)
    }
}

@MainActor
final class BodyReadProbe {
    var calls = 0
    var before: (() throws -> Void)?
    var after: (() throws -> Void)?
    func observe(_ event: ContentQueryBodyReadEvent) throws {
        switch event {
        case .willRead: calls += 1; try before?()
        case .didRead: try after?()
        }
    }
}
