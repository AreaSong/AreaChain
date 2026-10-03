import Foundation
import Testing
@testable import AreaChain

@MainActor
final class SearchReadFixture {
    let handoff: HandoffFixture
    let data: DiaryContentQueryFixture
    let system = FakeSystemVaultKeys()
    let vault: PrivacyVault
    let owner: ContentQueryReadOwner
    let model = NotificationCenter()
    let focus = NotificationCenter()
    let focusObject = NSObject()
    let session: ContentQueryReadSession
    static let focusLost = Notification.Name("synthetic.search.focusLost")

    init(bodyMode: Bool = false, imageMode: Bool = false,
         configureTrash: ((inout TrashContentQueryReads) -> Void)? = nil,
         configureImages: ((inout ImageContentQueryReads) -> Void)? = nil,
         configureTagUsage: ((inout TagUsageContentQueryReads) -> Void)? = nil,
         configure: ((inout ContentQueryBodyReads) -> Void)? = nil) throws {
        handoff = try .init(sourcePage: .overview)
        data = try .init()
        data.diary()
        vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system)
        owner = try .init(paginationPolicy: .init(units: 1, members: 1, contexts: 1))
        try handoff.send(.query(.setInput("/diaries")))
        let notifications = ContentQueryReadNotifications(privacy: .default, model: model, focus: focus,
            focusLost: Self.focusLost, focusObject: focusObject)
        if let configureTagUsage {
            var reads = TagUsageContentQueryReads(context: data.context)
            configureTagUsage(&reads)
            session = try ContentQueryReadSession(vault: vault, tagUsageReads: reads, coordinator: handoff.coordinator,
                ownership: handoff.owned().lease.ownership, notifications: notifications)
        } else if let configureTrash {
            var bodies = ContentQueryBodyReads(context: data.context)
            configure?(&bodies)
            var reads = TrashContentQueryReads(context: data.context, bodies: bodies)
            configureTrash(&reads)
            session = try ContentQueryReadSession(vault: vault, trashReads: reads, coordinator: handoff.coordinator,
                ownership: handoff.owned().lease.ownership, notifications: notifications)
        } else if imageMode {
            var bodies = ContentQueryBodyReads(context: data.context)
            configure?(&bodies)
            var reads = ImageContentQueryReads(context: data.context, bodies: bodies)
            configureImages?(&reads)
            session = try ContentQueryReadSession(vault: vault, imageReads: reads, coordinator: handoff.coordinator,
                ownership: handoff.owned().lease.ownership, notifications: notifications)
        } else if bodyMode {
            var reads = ContentQueryBodyReads(context: data.context)
            configure?(&reads)
            session = try ContentQueryReadSession(vault: vault, bodyReads: reads, coordinator: handoff.coordinator,
                ownership: handoff.owned().lease.ownership, notifications: notifications)
        } else {
            session = try ContentQueryReadSession(vault: vault, owner: owner, coordinator: handoff.coordinator,
                ownership: handoff.owned().lease.ownership, notifications: notifications)
        }
        session.install()
    }

    var lease: CommandHostLease { get throws { try handoff.owned().lease } }
    var query: ContentQuerySession { get throws { try handoff.state().query } }

    func batch(_ query: ContentQuerySession) -> ContentQueryBatch {
        TaskFamilyContentQueryReader(context: data.context, diaryMode: .metadataOnly)
            .read(session: query, requestID: UUID(), observation: RoutineContentQueryFixture.observation()).batch
    }

    @discardableResult
    func publish() async throws -> ContentQueryReadHandle {
        let handle = try session.prepare(read: batch)
        try session.evaluate(handle)
        #expect(try await session.publish(handle).outcome == .published)
        return handle
    }

    func unlock() async throws {
        if vault.configuration == nil { try await vault.create(password: nil, systemUnlock: true) }
        else { try await vault.unlockWithSystem(reason: "Synthetic search lifecycle") }
        await settle()
    }

    func settle() async {
        for _ in 0..<200 where !session.isTrackingReady { await Task.yield() }
        #expect(session.isTrackingReady)
    }

    func expectEmpty() throws {
        let query = try query
        #expect(try QuerySessionFixture.source(query) == "")
        #expect(query.conditions.isEmpty && query.returnPoint == nil && query.handoffContext == nil)
        #expect(query.suppressed.isEmpty && query.page.location.reference.isEmpty)
        #expect(query.binding == .independent(.privacyInvalidated))
        #expect(owner.source == nil && owner.request == nil && owner.published == nil)
        #expect(!session.hasRetainedPresentation && !session.hasCompletionBuffer)
        #expect(!session.hasPublicationPermit)
    }
}
