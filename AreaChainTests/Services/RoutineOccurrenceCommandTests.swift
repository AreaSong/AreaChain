import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineOccurrenceCommandTests {
    @Test(arguments: ["complete", "skip", "reopen"], Array(0...4))
    func explicitTransitionsAndAbsentRows(action: String, encoding: Int) throws {
        let f = try RoutineStateFixture(enabled: true)
        let day = "2026-10-07"
        f.history(day)
        let row = encoding == 4 ? nil : f.row(day, encoding & 2 != 0, encoding & 1 != 0)
        let otherDay = f.row("2026-10-06", true)
        try f.context.save()
        let definition = f.routine.snapshot
        let originalID = row?.id
        let accepted = try f.accept("occurrence." + action, day: day)
        let expectedDone = action != "reopen", expectedSkipped = action == "skip"
        let noChange = encoding == 4 ? action == "reopen" : (encoding & 2 != 0) == expectedDone && (encoding & 1 != 0) == expectedSkipped
        #expect(accepted.object == .init(type: .routineOccurrence, id: f.routine.id, dayKey: day))
        #expect(accepted.preview.noChange == noChange)
        let facts = try f.base.submit(accepted)
        #expect(facts.state == (noChange ? .noChange : .saved))
        let actual = f.routine.checks.filter { $0.dayKey == day }
        if encoding == 4 && action == "reopen" { #expect(actual.isEmpty && accepted.checkCreationIDs.isEmpty) }
        else {
            let actual = try #require(actual.count == 1 ? actual.first : nil)
            #expect(actual.id == (originalID ?? accepted.checkCreationIDs[day]))
            #expect(actual.isDone == expectedDone && actual.isSkipped == expectedSkipped && actual.routine === f.routine)
            #expect(actual.id != facts.object.id)
        }
        #expect(f.routine.snapshot == definition && otherDay.isDone && !otherDay.isSkipped)
        #expect(f.base.count("save") == (noChange ? 0 : 1) && f.base.count("ui") == (noChange ? 0 : 1))
        #expect(try f.context.fetchCount(FetchDescriptor<DailyRoutine>()) == 2)
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
    }

    @Test(arguments: [0, 1, 2, 3]) func multiplePhysicalRowsAlwaysReject(kind: Int) throws {
        let f = try RoutineStateFixture(enabled: true)
        f.row(f.base.today, kind & 2 != 0, kind & 1 != 0)
        f.row(f.base.today, kind & 2 != 0, kind & 1 != 0)
        try f.context.save()
        let before = try f.base.checks()
        try f.queue("occurrence.complete", day: f.base.today)
        #expect(throws: RoutineStateIssue.duplicateRows) { try f.base.preview() }
        #expect(try f.base.checks() == before && f.base.count("save") == 0)
    }

    @Test(arguments: [0, 1, 2, 3]) func eligibilityCannotBeInvented(kind: Int) throws {
        let f = try RoutineStateFixture(enabled: kind != 1)
        let day = kind == 0 ? "2026-10-07" : kind == 2 ? "2026-08-31" : f.base.today
        if kind == 3 { f.routine.weekdayMask = WeekdayMask.only(weekday: 2) }
        f.row(day, true)
        try f.context.save()
        try f.queue("occurrence.skip", day: day)
        #expect(throws: (any Error).self) { try f.base.preview() }
        #expect(f.base.count("save") == 0)
    }

    @Test(arguments: [0, 1, 2]) func wrongTypeDateAndPhysicalIdentityAreRejected(kind: Int) throws {
        let f = try RoutineStateFixture(enabled: true)
        let row = f.row(f.base.today)
        try f.context.save()
        let target = CommandObjectReference(type: kind == 0 ? .routine : .routineOccurrence,
            id: kind == 2 ? row.id : f.routine.id, dayKey: kind == 0 ? nil : kind == 1 ? "2026-02-30" : f.base.today)
        try f.base.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "occurrence.complete"),
            targets: .init(.single, objects: [target]), arguments: []))
        #expect(throws: (any Error).self) { try f.base.preview() }
        #expect(f.base.count("save") == 0)
    }
}
