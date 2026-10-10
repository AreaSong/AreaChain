import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchNavigationOwnershipTests {
    @Test(arguments: [0, 1, 2, 3]) func navigationPreservesPlanRunUnknownAndRevisions(_ mode: Int) async throws {
        let fields = try TaskFieldCommandFixture()
        let support = UnifiedSearchPlanRevisionTests()
        let original = try support.fieldFixture(fields)
        defer { original.stop() }
        try support.queueFields(original, fields: fields, kinds: [0, 1])
        let adapter = try #require(original.controller.multiPlan)
        if mode == 2 { fields.io.saveMode = .throwAfter }
        if mode == 3 { fields.io.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected } }
        if mode > 0 { try MultiPlanRevisionSupport.start(adapter, original.handoff, maximum: 1) }
        if mode == 3 { _ = try MultiPlanRevisionSupport.returnAll(adapter, original.handoff) }
        _ = original.controller.publishOperation(text: "/tasks")
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start(controller: original.controller)
        let before = try original.handoff.state()
        let ownership = try original.handoff.owned().lease.ownership
        let saves = fields.count("save"), events = fields.count("ui")
        try await fixture.go("/go/settings")
        #expect(fixture.router.outcome == .displayed)
        #expect(try original.handoff.state() == before)
        try await fixture.back()
        #expect(try original.handoff.state() == before)
        #expect(try original.handoff.owned().lease.ownership == ownership)
        #expect(fields.count("save") == saves && fields.count("ui") == events)
        if mode == 2 { #expect(original.controller.settingExecution?.hasUnknownCommit == true) }
        if mode == 1 { #expect(original.controller.settingExecution?.units.first?.state == .succeeded) }
        try await fixture.snapshot("ownership-\(mode)")
    }
}
