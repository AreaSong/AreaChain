import Foundation
import Testing
@testable import AreaChain

struct SyncPortTests {
    @Test func encodeAndDecodeRoundTrip() throws {
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_788_800_000),
            routines: [
                ExportedRoutine(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    title: "写日报",
                    sortOrder: 0,
                    isEnabled: true,
                    createdDayKey: "2026-09-01"
                )
            ],
            checks: [],
            todos: [
                ExportedTodo(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    title: "修角标",
                    isDone: false,
                    dayKey: "2026-09-07",
                    createdAt: Date(timeIntervalSince1970: 1_788_800_100)
                )
            ],
            diaries: []
        )
        let data = try SyncPort.encode(snapshot)
        let decoded = try SyncPort.decode(data)
        #expect(decoded == snapshot)
    }

    @Test func decodeCheckWithoutSkippedDefaultsFalse() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [],
          "checks": [
            {
              "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
              "routineId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "dayKey": "2026-09-07",
              "isDone": true
            }
          ],
          "todos": [],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.checks.first?.isSkipped == false)
        #expect(decoded.checks.first?.isDone == true)
    }
}
