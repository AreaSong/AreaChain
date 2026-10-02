import Foundation
import Testing
@testable import AreaChain

enum RoutineProviderFixture {
    static func read(
        _ source: String, routines: [RoutineSnapshot] = [RoutineQueryFixture.routine()],
        evidence: [RoutineScheduleEvidence] = [], checks: [CheckSnapshot] = [],
        coverage: [RoutineCheckCoverage] = [], names: [UUID: String]? = nil
    ) -> RoutineQueryResponse {
        read(TodoQueryFixture.session(source), routines: routines, evidence: evidence,
             checks: checks, coverage: coverage, names: names)
    }

    static func read(
        _ session: ContentQuerySession, routines: [RoutineSnapshot] = [RoutineQueryFixture.routine()],
        evidence: [RoutineScheduleEvidence] = [], checks: [CheckSnapshot] = [],
        coverage: [RoutineCheckCoverage] = [], names: [UUID: String]? = nil
    ) -> RoutineQueryResponse {
        RoutineQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session, routines: routines,
                                       tagNames: names, checks: checks, checkCoverage: coverage, scheduleEvidence: evidence))
    }

    static let complete = RoutineCheckCoverage(routineID: RoutineQueryFixture.id,
                                               completeIntervals: [QuerySessionFixture.interval("2026-09-01", "2026-10-10")])
    static let schedule = RoutineQueryFixture.evidence("2026-09-01", "2026-10-10")
}

struct RoutineQueryProviderTests {
    @Test func plainDefinitionNeedsNoAuxiliaryData() throws {
        let response = RoutineProviderFixture.read("合成")
        let match = try #require(response.matches.first)
        #expect(response.isCompleteForCoveredTypes)
        #expect(response.coverage.isPartialTypeCoverage)
        #expect(match.id.type == .routine && match.id.dayKey == nil)
        #expect(match.dateExistence == nil && match.occurrence == nil)
        #expect(match.isEnabled)
        #expect(match.evidence.contains { $0.field == .title && $0.range == NSRange(location: 0, length: 2) })
    }

    @Test func scopeAndInactiveComposition() {
        var routine = RoutineQueryFixture.routine()
        routine.isEnabled = false
        for source in ["合成", "/tasks 合成"] {
            #expect(RoutineProviderFixture.read(source, routines: [routine]).matches.isEmpty)
        }
        #expect(RoutineProviderFixture.read("/routines 合成", routines: [routine]).matches.count == 1)
        let session = TodoQueryFixture.add(.page(.routineStatus(.disabled)), to: TodoQueryFixture.session("/tasks"))
        #expect(RoutineProviderFixture.read(session, routines: [routine]).matches.count == 1)
        #expect(RoutineProviderFixture.read("/diaries").state == .notApplicable)
        #expect(RoutineProviderFixture.read("/trash").state == .notApplicable)
    }

    @Test func textTagsUnicodeAndProperties() throws {
        var routine = RoutineQueryFixture.routine()
        routine.title = "👩🏽‍💻 Café 习惯"
        routine.notes = "两词 短语 合成备注"
        routine.tagIDs = TagIDList.encode([TodoQueryFixture.work])
        routine.isImportant = true
        routine.remindMinutes = 540
        routine.sourceBundleID = "fixture.app"
        routine.createdAt = TodoQueryFixture.created
        let response = RoutineProviderFixture.read("/routines cafe \"两词 短语\" -不存在 #工作 !p2 @09:00",
                                                    routines: [routine], names: TodoQueryFixture.names)
        let match = try #require(response.matches.first)
        #expect(match.notes == routine.notes)
        let range = try #require(match.evidence.first { $0.field == .title }?.range)
        #expect((match.title as NSString).substring(with: range) == "Café")
        #expect(RoutineProviderFixture.read("/routines (不存在 | cafe)", routines: [routine]).matches.count == 1)
        #expect(RoutineProviderFixture.read("/routines cafe 不存在", routines: [routine]).matches.isEmpty)
        #expect(RoutineProviderFixture.read("/routines -cafe", routines: [routine]).matches.isEmpty)
        var session = TodoQueryFixture.session("/routines")
        for value: ContentQueryConditionValue in [.page(.tagID(TodoQueryFixture.work)), .page(.sourceApplication("fixture.app")),
                                                  .page(.taskPriority(.init(scope: .p2))), .page(.todoStatus(.done)),
                                                  .page(.itemKind(.recurring))] {
            session = TodoQueryFixture.add(value, to: session)
        }
        #expect(RoutineProviderFixture.read(session, routines: [routine]).matches.count == 1)
        session = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session("/routines"))
        #expect(RoutineProviderFixture.read(session, routines: [routine]).matches.isEmpty)
        let created = DayKey.from(routine.createdAt, calendar: RoutineQueryFixture.dates.calendar)
        #expect(RoutineProviderFixture.read("/routines created:" + created, routines: [routine]).matches.count == 1)
    }

    @Test func duplicateIdentityIncludesDeletedAndPreservesOrder() {
        let routine = RoutineQueryFixture.routine()
        var deleted = routine
        deleted.deletedAt = TodoQueryFixture.created
        var other = routine
        other.id = TodoQueryFixture.work
        let response = RoutineProviderFixture.read("/routines", routines: [routine, other, deleted])
        #expect(response.matches.map(\.id.id) == [other.id])
        #expect(response.undeterminedObjects.map(\.id) == [routine.id])
        #expect(response.diagnostics.first?.inputIndices == [0, 2])
        #expect(!response.isCompleteForCoveredTypes)
    }

    @Test func invalidInputsAndCapabilitiesAreNotEmptySuccess() {
        var invalid = RoutineQueryFixture.routine()
        invalid.createdAt = Date(timeIntervalSince1970: .nan)
        invalid.createdDayKey = "bad"
        let response = RoutineProviderFixture.read("不匹配", routines: [invalid])
        #expect(response.diagnostics.map(\.issue) == [.invalidCreatedDay, .invalidCreatedAt])
        #expect(response.undeterminedObjects.count == 1)
        let image = RoutineProviderFixture.read("/routines has:image")
        #expect(image.matches.isEmpty && !image.isCompleteForCoveredTypes)
        #expect(image.diagnostics.contains { $0.issue == .imageAssociationUnavailable })
        #expect(RoutineProviderFixture.read("/routines status:done").state == .requiresInput)
        #expect(RoutineProviderFixture.read("/routines date:today status:done").state == .requiresInput)
        #expect(RoutineProviderFixture.read("/routines on:bad").state == .invalidQuery)
        #expect(RoutineProviderFixture.read("/routines on:today status:done status:open").state == .unsatisfiable)
    }

    @Test func knownFailureDominatesUnknownWithoutDroppingDiagnostic() {
        let response = RoutineProviderFixture.read("/routines 不存在 has:image")
        #expect(response.matches.isEmpty && response.undeterminedObjects.isEmpty)
        #expect(response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains { $0.issue == .imageAssociationUnavailable && !$0.affectsDetermination })
        var routine = RoutineQueryFixture.routine()
        routine.tagIDs = TagIDList.encode([TodoQueryFixture.work])
        let missing = RoutineProviderFixture.read("/routines #工作", routines: [routine], names: [:])
        #expect(missing.undeterminedObjects.count == 1)
        #expect(missing.diagnostics.first?.issue == .missingAssociatedTagName(TodoQueryFixture.work))
    }

    @Test func descriptionsRedactContents() {
        let response = RoutineProviderFixture.read("合成")
        #expect(!String(describing: response).contains("合成"))
        #expect(!String(reflecting: response.matches[0]).contains("合成"))
    }
}
