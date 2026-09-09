import Foundation
import Testing
@testable import AreaChain

struct SoftDeleteTests {
    @Test func restoreOnlyMatchesIdenticalStamp() {
        let stamp = Date(timeIntervalSince1970: 100)
        #expect(SoftDelete.shouldRestoreChild(parentDeletedAt: stamp, childDeletedAt: stamp))
        #expect(
            !SoftDelete.shouldRestoreChild(
                parentDeletedAt: stamp,
                childDeletedAt: Date(timeIntervalSince1970: 99)
            )
        )
        #expect(!SoftDelete.shouldRestoreChild(parentDeletedAt: stamp, childDeletedAt: nil))
        #expect(!SoftDelete.shouldRestoreChild(parentDeletedAt: nil, childDeletedAt: stamp))
    }

    @Test func exportDatesRoundTripKeepsFractionalSeconds() throws {
        let original = Date(timeIntervalSince1970: 1_788_800_000.25)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = ExportDates.encodeStrategy()
        let data = try encoder.encode(["at": original])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ExportDates.decodeStrategy()
        let decoded = try decoder.decode([String: Date].self, from: data)
        #expect(decoded["at"] == original)

        let legacy = Data(#"{"at":"2026-09-07T00:00:00Z"}"#.utf8)
        let whole = try decoder.decode([String: Date].self, from: legacy)
        #expect(whole["at"] != nil)
    }
}
