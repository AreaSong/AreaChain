import Foundation
import Testing
@testable import AreaChain

struct CommandHostSessionTests {
    @Test func queryNavigationAndPresentationNeverRewriteOperation() throws {
        var host = CommandHostSession(page: QuerySessionFixture.page())
        let target = DraftFixture.object(.diary)
        let draft = DraftFixture.draft("diary.body", targets: .init(.allResults, objects: [target]))
        host.operationEvent(.start(expectedRevision: 0, draft))
        host.operationEvent(.edit(try #require(host.operations.active?.stamp), DraftFixture.body("Synthetic long\nbody")))
        let operations = host.operations
        host.queryEvent(.setInput("Synthetic query"))
        host.queryEvent(.enterPage(QuerySessionFixture.page(.settings, visit: "settings")))
        host.queryEvent(.setInput("/setting/language/chinese"))
        #expect(host.operations == operations)
        let intents = host.queryEvent(.clearUserQuery)
        #expect(intents.contains { if case .returnToPage = $0 { return true }; return false })
        for event in CommandHostPresentationEvent.allCases { host.presentationEvent(event) }
        #expect(host.operations == operations)
        #expect(host.operations.active?.targets.objects == [target])
    }

    @Test func hostsDoNotShareParametersOrAcceptForeignEvents() throws {
        var first = CommandHostSession(page: QuerySessionFixture.page())
        var second = CommandHostSession(page: QuerySessionFixture.page(host: "menubar"))
        first.operationEvent(.start(expectedRevision: 0, DraftFixture.draft("diary.create")))
        first.operationEvent(.edit(try #require(first.operations.active?.stamp), DraftFixture.body("Synthetic workspace")))
        let secondBefore = second
        #expect(second.operationEvent(.edit(try #require(first.operations.active?.stamp), DraftFixture.body("Synthetic foreign"))) == [.rejectedEvent])
        #expect(second.operationEvent(.start(expectedRevision: 0, DraftFixture.draft("diary.create"))) == [.rejectedEvent])
        #expect(second == secondBefore)
        let seed = CommandDraft(id: UUID(), hostID: "menubar", commandID: .init(rawValue: "setting.language"))
        second.operationEvent(.start(expectedRevision: 0, seed))
        second.queryEvent(.setInput("Synthetic independent"))
        #expect(second.operations.active?.arguments.isEmpty == true)
        #expect(first.operations.active?.arguments == [DraftFixture.body("Synthetic workspace")])
    }
}
