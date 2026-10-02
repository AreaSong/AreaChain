import Foundation
import Testing
@testable import AreaChain

struct ImageQueryIntegrationTests {
    @Test func rawImagesSessionAssociationAndProviderPreserveIdentity() {
        let request = ImageQueryFixture.request("/images (missing | photo) #工作 created:2023-11-15")
        let before = request.session
        let association = ImageAssociationReader.read(request.association)
        let response = ImageQueryProvider.read(request)
        #expect(request.session == before && response.queryIsValid && response.state == .evaluated)
        #expect(response.matches.map(\.id) == association.images.map(\.id))
        #expect(response.requestID == request.requestID && response.typeAnalysis == before.typeAnalysis)
        #expect(response.matches.allSatisfy { match in match.evidence.allSatisfy { item in before.conditions.contains { $0.id == item.conditionID } } })
    }

    @Test func imagesPageHasOnlyRealScopeAndNoInventedTypeControl() {
        let page = QuerySessionFixture.page(.images)
        #expect(ContentQueryPageMapping.defaults(page) == [.scope(.catalog(.images))])
        let session = TodoQueryFixture.session("photo", page: .images)
        let response = ImageQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session,
                                                    association: ImageQueryFixture.association()))
        #expect(response.matches.count == 3)
        var owners = ImageQueryFixture.owners
        owners.routines?[0].isEnabled = false
        #expect(ImageQueryFixture.read("/images photo", association: ImageQueryFixture.association(owners: owners)).matches.count == 3)
    }

    @Test func tagPageUserTakeoverAndHandoffFrozenConditionsAllParticipate() {
        var owners = ImageQueryFixture.owners
        owners.routines?[0].tagIDs = TodoQueryFixture.study.uuidString
        let association = ImageQueryFixture.association(owners: owners)
        let page = ContentQueryPage.tagContents(tagID: TodoQueryFixture.work, types: [.todo, .diary, .image])
        let session = TodoQueryFixture.session("photo", page: page)
        func read(_ session: ContentQuerySession) -> ImageQueryResponse {
            ImageQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session,
                                          association: association, tagNames: ImageQueryFixture.names))
        }
        let automatic = read(session)
        #expect(automatic.matches.map(\.owner.kind) == [.todo, .diary])
        #expect(automatic.coverage.isPartialTypeCoverage)
        let takeover = ContentQueryReducer.reduce(session, .setInput("photo #学习")).state
        #expect(read(takeover).matches.map(\.owner.kind) == [.routine])
        let target = ContentQuerySession(page: QuerySessionFixture.page(.tagContents(tagID: TodoQueryFixture.study, types: [.image]), visit: "target"))
        let frozen = session.handedOff(to: target)
        #expect(read(frozen).matches.map(\.id) == automatic.matches.map(\.id))
        #expect(read(frozen).matches[0].evidence.contains { evidence in
            frozen.conditions.contains { $0.id == evidence.conditionID && $0.origin.isHandoffPage }
        })
    }

    @Test func ownerPagePriorityReminderAndDateAreNotDiscarded() {
        let base = TodoQueryFixture.session("/images photo")
        for condition: ContentQueryConditionValue in [.page(.taskPriority(.init(scope: .p2))), .page(.reminderPresence(.set))] {
            let session = TodoQueryFixture.add(condition, to: base)
            let response = ImageQueryProvider.read(.init(requestID: UUID(), session: session, association: ImageQueryFixture.association()))
            #expect(response.matches.map(\.owner.kind) == [.todo, .routine])
        }
        for evaluation in [ContentQueryPageDateRule.Evaluation.items, .listedDay, .agenda] {
            let scope: DateFilterScope = evaluation == .agenda ? .upcoming : .today
            let rule = ContentQueryPageDateRule(evaluation: evaluation, todayKey: "2026-10-01", calendar: ImageQueryFixture.dates.calendar)
            let session = TodoQueryFixture.add(.page(.boardDate(scope, rule)), to: base)
            let response = ImageQueryProvider.read(.init(requestID: UUID(), session: session, association: ImageQueryFixture.association()))
            let todo = ImageQueryFixture.owners.todos![0]
            #expect(response.matches.contains { $0.owner.kind == .todo } == TodoQueryPageRules.boardDate(scope, rule: rule, todo: todo))
            #expect(response.undeterminedObjects.count == 1)
            #expect(response.diagnostics.contains { $0.issue == .unsupportedOwnerPageDate })
        }
    }

    @Test func missingSourceIsExplicitAndDefiniteMissStillExcludes() {
        for text in ["photo", "missing"] {
            let session = TodoQueryFixture.add(.page(.sourceApplication("synthetic.app")), to: TodoQueryFixture.session("/images " + text))
            let response = ImageQueryProvider.read(.init(requestID: UUID(), session: session, association: ImageQueryFixture.association()))
            #expect(response.matches.isEmpty)
            #expect(response.undeterminedObjects.count == (text == "photo" ? 2 : 0))
            #expect(response.diagnostics.contains { $0.issue == .ownerSourceUnavailable })
        }
    }
}
