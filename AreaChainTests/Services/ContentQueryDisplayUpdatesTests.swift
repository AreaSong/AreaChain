import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryDisplayUpdatesTests {
    @Test func notificationsAndPublicBodyExpansionRecheckGate() async throws {
        let fixture = try SearchReadFixture(bodyMode: true)
        defer { fixture.session.detach() }
        fixture.data.diary(String(repeating: "synthetic public long text ", count: 60))
        var changes: [ContentQueryDisplayUpdates.Change] = []
        let token = fixture.session.displayUpdates.observe { changes.append($0) }
        defer { fixture.session.displayUpdates.remove(token) }
        let handle = try fixture.session.prepareBodies(observation: RoutineContentQueryFixture.observation())
        try fixture.session.evaluate(handle)
        try await fixture.session.publish(handle)
        #expect(changes.last == .published)
        let page = try fixture.session.presentation().pagination
        let reference = try #require(page.snapshot.source.rows.flatMap(\.expansion).first)
        let control = ContentQueryDisplayControl.body(reference.object, reference.field)
        #expect(throws: ContentQueryReadSessionError.self) { try fixture.session.expandedText(control, version: page.snapshot.version) }
        _ = try fixture.session.browse(.init(version: page.snapshot.version, action: .expand(.bodyToggle(reference.object, reference.field))))
        #expect(try fixture.session.expandedText(control, version: page.snapshot.version).contains("synthetic public"))
        fixture.vault.lock()
        #expect(changes.contains(.invalidated) && changes.last == .privacyInvalidated)
        #expect(throws: ContentQueryReadSessionError.self) { try fixture.session.expandedText(control, version: page.snapshot.version) }
    }

    @Test func changingOwnerCannotRebindOldCallbacks() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let source = fixture.controller.buffer
        let page = try fixture.page
        _ = try fixture.handoff.transfer()
        #expect(!fixture.controller.validates(source))
        fixture.controller.browse(.init(version: page.snapshot.version, action: .selectAllKnown), source: source)
        fixture.controller.load(.init(stamp: page.stamp, action: .loadMoreUnits), source: source)
        #expect(fixture.controller.edit(.init(source: source, text: "old", selection: .init(location: 3, length: 0))) == nil)
        #expect(fixture.opens.isEmpty)
        #expect(throws: ContentQueryReadSessionError.self) { try fixture.session.presentation() }
    }
}
