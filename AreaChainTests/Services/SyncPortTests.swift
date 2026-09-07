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

    @Test func decodeRoutineWithoutWeekdaysOnlyDefaultsFalse() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [
            {
              "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "title": "复盘",
              "sortOrder": 1,
              "isEnabled": true,
              "createdDayKey": "2026-09-01"
            }
          ],
          "checks": [],
          "todos": [],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.routines.first?.weekdaysOnly == false)
        #expect(decoded.routines.first?.weekdayMask == WeekdayMask.all)
        #expect(decoded.routines.first?.title == "复盘")
        #expect(decoded.routines.first?.createdAt == nil)
        #expect(decoded.routines.first?.remindMinutes == nil)
    }

    @Test func decodeMissingRemindMinutesAsNil() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [],
          "checks": [],
          "todos": [
            {
              "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
              "title": "修角标",
              "isDone": false,
              "dayKey": "2026-09-07",
              "createdAt": "2026-09-07T01:00:00Z"
            }
          ],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.todos.first?.remindMinutes == nil)
        #expect(decoded.todos.first?.deletedAt == nil)
        #expect(decoded.todos.first?.title == "修角标")
    }

    @Test func decodeMissingDeletedAtAsNil() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [
            {
              "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "title": "复盘",
              "sortOrder": 1,
              "isEnabled": true,
              "createdDayKey": "2026-09-01"
            }
          ],
          "checks": [],
          "todos": [],
          "diaries": [
            {
              "id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
              "text": "一句",
              "dayKey": "2026-09-07",
              "createdAt": "2026-09-07T01:00:00Z"
            }
          ]
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.routines.first?.deletedAt == nil)
        #expect(decoded.diaries.first?.deletedAt == nil)
    }

    @Test func decodeOldWeekdaysOnlyAsWorkdaysMask() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [
            {
              "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "title": "写日报",
              "sortOrder": 0,
              "isEnabled": true,
              "createdDayKey": "2026-09-01",
              "weekdaysOnly": true
            }
          ],
          "checks": [],
          "todos": [],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.routines.first?.weekdayMask == WeekdayMask.workdays)
        #expect(decoded.routines.first?.weekdaysOnly == true)
    }

    @Test func decodeWeekdayMaskWinsOverWeekdaysOnly() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [
            {
              "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "title": "周会",
              "sortOrder": 0,
              "isEnabled": true,
              "createdDayKey": "2026-09-01",
              "weekdaysOnly": true,
              "weekdayMask": 8
            }
          ],
          "checks": [],
          "todos": [],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.routines.first?.weekdayMask == 8)
        #expect(decoded.routines.first?.weekdaysOnly == false)
    }

    @Test func encodeKeepsRemindMinutesAndCreatedAt() throws {
        let created = Date(timeIntervalSince1970: 1_788_800_000)
        let snapshot = ExportSnapshot(
            exportedAt: created,
            routines: [
                ExportedRoutine(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    title: "写日报",
                    sortOrder: 0,
                    isEnabled: true,
                    createdDayKey: "2026-09-01",
                    weekdaysOnly: true,
                    createdAt: created,
                    remindMinutes: 9 * 60
                )
            ],
            checks: [],
            todos: [
                ExportedTodo(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    title: "修角标",
                    isDone: false,
                    dayKey: "2026-09-07",
                    createdAt: created,
                    remindMinutes: 18 * 60 + 30
                )
            ],
            diaries: []
        )
        let decoded = try SyncPort.decode(try SyncPort.encode(snapshot))
        #expect(decoded == snapshot)
        #expect(decoded.routines.first?.remindMinutes == 540)
        #expect(decoded.routines.first?.weekdayMask == WeekdayMask.workdays)
        #expect(decoded.todos.first?.remindMinutes == 1110)
    }

    @Test func decodeMissingClassifyFieldsAsEmpty() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [
            {
              "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "title": "复盘",
              "sortOrder": 1,
              "isEnabled": true,
              "createdDayKey": "2026-09-01"
            }
          ],
          "checks": [],
          "todos": [
            {
              "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
              "title": "修角标",
              "isDone": false,
              "dayKey": "2026-09-07",
              "createdAt": "2026-09-07T01:00:00Z"
            }
          ],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.projects.isEmpty)
        #expect(decoded.tags.isEmpty)
        #expect(decoded.attachments.isEmpty)
        #expect(decoded.routines.first?.projectID == nil)
        #expect(decoded.routines.first?.tagIDs == "")
        #expect(decoded.routines.first?.isImportant == false)
        #expect(decoded.todos.first?.sourceBundleID == "")
        #expect(decoded.todos.first?.isUrgent == false)
    }

    @Test func encodeKeepsClassifyAndCatalog() throws {
        let projectID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let tagID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_788_800_000),
            routines: [],
            checks: [],
            todos: [
                ExportedTodo(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    title: "修角标",
                    isDone: false,
                    dayKey: "2026-09-07",
                    createdAt: Date(timeIntervalSince1970: 1_788_800_100),
                    projectID: projectID,
                    tagIDs: tagID.uuidString,
                    isImportant: true,
                    isUrgent: true,
                    sourceBundleID: "com.apple.Safari"
                )
            ],
            diaries: [],
            projects: [ExportedProject(id: projectID, name: "工作", sortOrder: 0)],
            tags: [ExportedTag(id: tagID, name: "跟进", sortOrder: 0)],
            attachments: [
                ExportedAttachment(
                    id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
                    ownerKind: "todo",
                    ownerID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    filename: "shot.png",
                    createdAt: Date(timeIntervalSince1970: 1_788_800_200)
                )
            ]
        )
        let decoded = try SyncPort.decode(try SyncPort.encode(snapshot))
        #expect(decoded == snapshot)
        #expect(decoded.todos.first?.isImportant == true)
        #expect(decoded.projects.first?.name == "工作")
        #expect(decoded.attachments.first?.filename == "shot.png")
    }
}
