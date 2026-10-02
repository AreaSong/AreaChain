import Foundation
import Testing
@testable import AreaChain

struct TagQueryBoundaryTests {
    @Test(arguments: ["#工作", "-#工作", "(#工作 | #学习)", "date:2026-10-01", "created:2026-10-01",
                      "status:done", "status:open", "status:skipped", "!p1", "@15:30", "on:2026-10-01", "has:image"])
    func unsupportedOwnFieldsAreInapplicable(_ term: String) {
        let source = "/tags " + term
        let session = TodoQueryFixture.session(source)
        let response = TagQueryFixture.read(session, [TagQueryFixture.tag(1)])
        #expect(response.queryIsValid)
        #expect(response.state == .inapplicableConditions && response.matches.isEmpty)
        #expect(response.typeAnalysis.assessment(for: .tag)?.reasons.contains { $0.issue == .fieldNotApplicable } == true)
        #expect(session == TodoQueryFixture.session(source))
    }

    @Test func unsupportedPageConditionsDoNotInventTagAssociations() {
        let tag = TagQueryFixture.tag(1)
        let predicates: [ContentQueryPagePredicate] = [
            .tagID(tag.id), .noTags, .taskPriority(.init(scope: .p1)), .reminderPresence(.set),
            .todoStatus(.done), .routineStatus(.enabled), .itemKind(.recurring), .sourceApplication("synthetic.app")
        ]
        for predicate in predicates {
            let session = TodoQueryFixture.add(.page(predicate), to: TodoQueryFixture.session("/tags"))
            let response = TagQueryFixture.read(session, [tag])
            #expect(response.state == .inapplicableConditions && response.matches.isEmpty)
        }
    }

    @Test func malformedUnsatisfiableInapplicableAndEmptyAreDifferent() {
        let tag = TagQueryFixture.tag(1)
        #expect(TagQueryFixture.read("/tags (工作 |", [tag]).state == .invalidQuery)
        #expect(TagQueryFixture.read("/tags 工作 -工作", [tag]).state == .unsatisfiable)
        #expect(TagQueryFixture.read("/tags #工作", [tag]).state == .inapplicableConditions)
        let empty = TagQueryFixture.read("/tags 无关", [tag])
        #expect(empty.state == .evaluated && empty.isCompleteForCoveredTypes && empty.matches.isEmpty)
    }

    @Test func duplicateIdentitiesIncludingTombstonesAreQuarantinedAsGroups() {
        let first = TagQueryFixture.tag(1)
        let sameName = TagQueryFixture.tag(2)
        var tombstone = first
        tombstone.deletedAt = Date(timeIntervalSince1970: 5)
        var deleted = TagQueryFixture.tag(3)
        deleted.deletedAt = Date(timeIntervalSince1970: 5)
        for tags in [[first, tombstone, sameName, deleted], [tombstone, first, sameName, deleted], [first, first, sameName]] {
            let result = TagQueryFixture.read("/tags", tags)
            #expect(result.matches.map(\.tag.id) == [sameName.id])
            #expect(result.undeterminedObjects == [.init(type: .tag, id: first.id)])
            #expect(result.diagnostics.first?.issue == .duplicateTagID)
            #expect(result.diagnostics.first?.inputIndices == [0, 1])
            #expect(!result.isCompleteForCoveredTypes)
        }
        #expect(TagQueryFixture.read("/tags", [first, sameName]).matches.count == 2)
    }

    @Test func scopeAndCombinationCoverageDoNotExpandResults() {
        let tags = [TagQueryFixture.tag(1)]
        for source in ["/trash", "/tasks", "/clipboard", "/images", "/diaries"] {
            let result = TagQueryFixture.read(source, tags)
            #expect(result.state == .notApplicable && result.coverage.coveredTypes.isEmpty)
        }
        let session = TodoQueryFixture.add(.page(.contentTypes([.tag, .todo])), to: TodoQueryFixture.session("工作"))
        let result = TagQueryFixture.read(session, tags)
        #expect(result.queryIsValid && result.matches.count == 1)
        #expect(result.coverage.requestedTypes == [.tag, .todo] && result.coverage.isPartialTypeCoverage)
        let impossible = TodoQueryFixture.add(.page(.contentTypes([.todo])), to: TodoQueryFixture.session("/tags"))
        #expect(TagQueryFixture.read(impossible, tags).state == .notApplicable)
        let invalid = TodoQueryFixture.add(.page(.contentTypes([.clipboardEntry, .tag])), to: TodoQueryFixture.session(""))
        #expect(TagQueryFixture.read(invalid, tags).state == .invalidQuery)
    }

    @Test func duplicateConditionIDsAreStructuralErrors() {
        var session = TodoQueryFixture.session("/tags 工作")
        session.conditions.append(session.conditions[0])
        let result = TagQueryFixture.read(session, [TagQueryFixture.tag(1)])
        #expect(result.state == .invalidQuery)
        #expect(result.conditionDiagnostics.contains { $0.issue == .ambiguousConditionIDs })
    }
}
