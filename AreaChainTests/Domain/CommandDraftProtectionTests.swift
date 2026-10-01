import Foundation
import Testing
@testable import AreaChain

struct CommandDraftProtectionTests {
    @Test func retainCancelDiscardAndRestoreProtectBothSides() throws {
        var state = DraftFixture.session()
        DraftFixture.start("diary.create", in: &state)
        DraftFixture.edit(DraftFixture.body("Synthetic first", operation: .assign), in: &state)
        let first = try #require(state.active)
        DraftFixture.start("setting.language", in: &state)
        let cancelled = try #require(state.pending)
        #expect(state.active == first)
        DraftFixture.apply(.resolve(cancelled, .cancel), to: &state)
        #expect(state.active == first)
        #expect(state.retained.isEmpty)
        DraftFixture.start("setting.language", in: &state)
        let retained = try #require(state.pending)
        DraftFixture.apply(.resolve(retained, .retain), to: &state)
        #expect(state.retained == [first])
        DraftFixture.edit(.init(parameter: .value, operation: .assign, value: .choice("english")), in: &state)
        let second = try #require(state.active)
        DraftFixture.apply(.restore(expectedRevision: state.revision, first.stamp), to: &state)
        #expect(state.active == second)
        let restore = try #require(state.pending)
        DraftFixture.apply(.resolve(restore, .retain), to: &state)
        #expect(state.active?.id == first.id)
        #expect(state.active?.arguments == first.arguments)
        #expect(state.active?.version == first.version + 1)
        #expect(state.retained == [second])
        DraftFixture.apply(.restore(expectedRevision: state.revision, second.stamp), to: &state)
        let discard = try #require(state.pending)
        DraftFixture.apply(.resolve(discard, .discard), to: &state)
        #expect(state.active?.id == second.id)
        #expect(state.retained.isEmpty)
    }

    @Test func cancelledRestoreKeepsBothDraftsAndRepeatedEditIsRejected() throws {
        var state = DraftFixture.session()
        DraftFixture.start("diary.create", in: &state)
        let stamp = try #require(state.active?.stamp)
        let edit = CommandDraftEvent.edit(stamp, DraftFixture.body("Synthetic retained", operation: .assign))
        DraftFixture.apply(edit, to: &state)
        let afterEdit = state
        #expect(DraftFixture.apply(edit, to: &state) == [.rejectedEvent])
        #expect(state == afterEdit)
        DraftFixture.start("setting.language", in: &state)
        DraftFixture.apply(.resolve(try #require(state.pending), .retain), to: &state)
        DraftFixture.edit(.init(parameter: .value, operation: .assign, value: .choice("english")), in: &state)
        let current = state.active, retained = state.retained
        DraftFixture.apply(.restore(expectedRevision: state.revision, try #require(retained.first?.stamp)), to: &state)
        DraftFixture.apply(.resolve(try #require(state.pending), .cancel), to: &state)
        #expect(state.active == current)
        #expect(state.retained == retained)
        #expect(state.unsavedDrafts.count == 2)
    }

    @Test func staleDecisionCandidateAndDuplicateRequestsCannotLoseEdits() throws {
        var state = DraftFixture.session()
        DraftFixture.start("diary.create", in: &state)
        DraftFixture.edit(DraftFixture.body("Synthetic initial", operation: .assign), in: &state)
        let oldStamp = try #require(state.active?.stamp)
        let request = CommandDraftEvent.start(expectedRevision: state.revision, DraftFixture.draft("setting.language"))
        DraftFixture.apply(request, to: &state)
        let pendingState = state
        #expect(DraftFixture.apply(request, to: &state) == [.rejectedEvent])
        #expect(state == pendingState)
        let decision = try #require(state.pending)
        DraftFixture.edit(DraftFixture.body("Synthetic newer", operation: .assign), in: &state)
        let edited = state
        #expect(DraftFixture.apply(.resolve(decision, .discard), to: &state) == [.rejectedEvent])
        #expect(DraftFixture.apply(.edit(oldStamp, DraftFixture.body("Synthetic stale")), to: &state) == [.rejectedEvent])
        #expect(state == edited)
        DraftFixture.start("setting.language", in: &state)
        let valid = try #require(state.pending)
        DraftFixture.apply(.resolve(valid, .retain), to: &state)
        let switched = state
        #expect(DraftFixture.apply(.resolve(valid, .retain), to: &state) == [.rejectedEvent])
        #expect(DraftFixture.apply(.edit(oldStamp, .init(parameter: .value, operation: .assign,
                                                      value: .choice("chinese"))), to: &state) == [.rejectedEvent])
        #expect(state == switched)
        #expect(state.retained.count == 1)
        #expect(state.retained[0].arguments == [DraftFixture.body("Synthetic newer", operation: .assign)])
    }

    @Test func retainedDiscardRejectsOldActivationAndReusedIdentity() throws {
        var state = DraftFixture.session()
        let seed = DraftFixture.draft("diary.create")
        DraftFixture.apply(.start(expectedRevision: 0, seed), to: &state)
        DraftFixture.edit(DraftFixture.body("Synthetic one", operation: .assign), in: &state)
        let first = try #require(state.active?.stamp)
        DraftFixture.start("setting.language", in: &state)
        DraftFixture.apply(.resolve(try #require(state.pending), .retain), to: &state)
        DraftFixture.apply(.restore(expectedRevision: state.revision, first), to: &state)
        DraftFixture.edit(DraftFixture.body("Synthetic two", operation: .assign), in: &state)
        DraftFixture.start("setting.language", in: &state)
        DraftFixture.apply(.resolve(try #require(state.pending), .retain), to: &state)
        let before = state
        #expect(DraftFixture.apply(.discardRetained(first), to: &state) == [.rejectedEvent])
        #expect(state == before)
        DraftFixture.apply(.discardRetained(try #require(state.retained.first?.stamp)), to: &state)
        #expect(state.retained.isEmpty)
        #expect(DraftFixture.apply(.start(expectedRevision: state.revision, seed), to: &state) == [.rejectedEvent])
    }

    @Test func targetChangesAreExplicitVersionedAndHaveOnlyOneOwner() throws {
        let first = DraftFixture.object(.todo), second = DraftFixture.object(.todo)
        var state = DraftFixture.session()
        DraftFixture.start("todo.tags", targets: .init(.allResults, objects: [first]), in: &state)
        let stamp = try #require(state.active?.stamp)
        #expect(DraftFixture.apply(.edit(stamp, .init(parameter: .target, operation: .assign,
                                                    value: .objects([second]))), to: &state) == [.rejectedEvent])
        #expect(state.active?.targets.objects == [first])
        DraftFixture.apply(.selectTargets(stamp, .init(.selected, objects: [second, first, second])), to: &state)
        #expect(state.active?.targets.objects == [second, first])
        #expect(state.active?.modification == .modified)
        let before = state
        #expect(DraftFixture.apply(.selectTargets(stamp, .none), to: &state) == [.rejectedEvent])
        #expect(state == before)
    }

    @Test func ambientOriginalCanBeRestoredWithoutConflatingValidation() throws {
        let baseline = CommandDraftBaseline([.init(subject: .ambient, parameter: .value): .uniform(.choice("english"))])
        var state = DraftFixture.session()
        DraftFixture.apply(.start(expectedRevision: 0, DraftFixture.draft("setting.language", baseline: baseline)), to: &state)
        #expect(state.active?.modification == .unchanged)
        #expect(state.active?.check().parametersComplete == false)
        DraftFixture.edit(.init(parameter: .value, operation: .assign, value: .choice("chinese")), in: &state)
        #expect(state.requiresUnsavedContentHandling)
        DraftFixture.edit(.init(parameter: .value, operation: .assign, value: .choice("english")), in: &state)
        #expect(!state.requiresUnsavedContentHandling)
        #expect(state.active?.check().parametersComplete == true)
        #expect(state.active?.check().isExecutable == false)
    }

    @Test func descriptionsNeverExposeSyntheticBodyOrParameters() throws {
        var state = DraftFixture.session()
        DraftFixture.start("diary.create", in: &state)
        let marker = "Synthetic-private-marker"
        DraftFixture.edit(DraftFixture.body(marker, operation: .assign), in: &state)
        let draft = try #require(state.active)
        let event = CommandDraftEvent.edit(draft.stamp, DraftFixture.body(marker))
        for text in [String(describing: draft), String(reflecting: draft), String(reflecting: state),
                     String(describing: event), String(reflecting: event)] {
            #expect(!text.contains(marker))
        }
    }
}
