import Foundation
import Testing
@testable import AreaChain

struct RecordImageQueryPresenceTests {
    typealias Fixture = RecordImageQueryFixture

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func fourStatesAreAdaptedWithoutImageDetails(_ kind: AttachmentOwner) {
        let present = Fixture.observe(kind, input: Fixture.input([Fixture.image(kind)]))
        #expect(present.matches.map(\.id) == [Fixture.id] && present.unknown.isEmpty && present.complete)
        let evidence = present.evidence.filter { $0.field == .imageAssociation }
        #expect(evidence.count == 1)
        #expect(evidence.first?.ownerObject == present.matches.first)
        #expect(evidence.first?.relatedObject == nil && evidence.first?.range == nil)
        let absent = Fixture.observe(kind, input: Fixture.input())
        #expect(absent.matches.isEmpty && absent.unknown.isEmpty && absent.complete)
        let unknown = Fixture.observe(kind, input: nil)
        #expect(unknown.matches.isEmpty && unknown.unknown.map(\.id) == [Fixture.id] && !unknown.complete)
        var protectedImage = Fixture.image(kind)
        protectedImage.protection = .protected
        let protected = Fixture.observe(kind, input: Fixture.input([protectedImage]))
        #expect(protected.matches.isEmpty && protected.unknown.map(\.id) == [Fixture.id] && !protected.complete)
        #expect(protected.issues == [.protectedAssociation])
        #expect(protected.evidence.isEmpty)
    }

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func providedEmptyNeedsCoverageAndNilImagesAreStillUnknown(_ kind: AttachmentOwner) {
        let key = AttachmentOwnerKey(kind: kind, id: Fixture.id)
        var coverage = ImageAssociationFixture.coverage
        coverage.associations.objects[key] = .notProvided
        let missing = Fixture.observe(kind, input: Fixture.input([], coverage: coverage))
        #expect(missing.unknown.map(\.id) == [Fixture.id])
        #expect(missing.issues.contains(.association(.associationCoverageIncomplete)))
        let nilImages = Fixture.observe(kind, input: Fixture.input(nil))
        #expect(nilImages.unknown.map(\.id) == [Fixture.id])
        #expect(nilImages.issues.contains(.association(.imagesNotProvided)))
    }

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func typedOwnerDoesNotBorrowOtherKinds(_ kind: AttachmentOwner) {
        let others: [AttachmentOwner] = [.todo, .routine, .diary].filter { $0 != kind }
        let result = Fixture.observe(kind, input: Fixture.input(others.map { Fixture.image($0) }))
        #expect(result.matches.isEmpty && result.unknown.isEmpty && result.complete)
    }

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func identityAndTombstoneRulesComeFromReader(_ kind: AttachmentOwner) {
        let image = Fixture.image(kind)
        var duplicate = image
        duplicate.deletedAt = ImageAssociationFixture.date
        let ambiguous = Fixture.observe(kind, input: Fixture.input([image, duplicate]))
        #expect(ambiguous.matches.isEmpty && ambiguous.unknown.map(\.id) == [Fixture.id])
        #expect(ambiguous.issues.contains(.association(.duplicateImageID)))
        let deleted = Fixture.observe(kind, input: Fixture.input([duplicate]))
        #expect(deleted.matches.isEmpty && deleted.unknown.isEmpty && deleted.complete)
        #expect(deleted.issues == [.association(.deletedImage)] && deleted.affects == [false])
        var coverage = ImageAssociationFixture.coverage
        coverage.imageIdentities.ids[image.id] = .partial
        let partial = Fixture.observe(kind, input: Fixture.input([image], coverage: coverage))
        #expect(partial.issues.contains(.association(.imageIdentityIncomplete)) && !partial.complete)
    }

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func localOwnerCoverageAndUnknownKindsNeverMeanAbsent(_ kind: AttachmentOwner) {
        var coverage = ImageAssociationFixture.coverage
        coverage.owners.objects[.init(kind: kind, id: Fixture.id)] = .partial
        let partial = Fixture.observe(kind, input: Fixture.input([], coverage: coverage))
        #expect(partial.unknown.map(\.id) == [Fixture.id])
        #expect(partial.issues.contains(.association(.ownerCoverageIncomplete)))
        var image = Fixture.image(kind)
        image.ownerKind = "unrecognized"
        let invalid = Fixture.observe(kind, input: Fixture.input([image]))
        #expect(invalid.unknown.map(\.id) == [Fixture.id])
        #expect(invalid.issues.contains(.association(.unknownOwnerKind)))
    }

    @Test func singleUnknownDoesNotBlockOtherRecords() {
        let input = Fixture.input([Fixture.image(.todo), Fixture.image(.routine), Fixture.image(.diary)], coverage: .init(
            owners: ImageAssociationFixture.coverage.owners,
            associations: .init(objects: [.init(kind: .todo, id: Fixture.id): .completeIncludingDeleted,
                                          .init(kind: .routine, id: Fixture.id): .completeIncludingDeleted,
                                          .init(kind: .diary, id: Fixture.id): .completeIncludingDeleted]),
            imageIdentities: .init(allIDs: .completeIncludingDeleted), diaryPrivacy: ImageAssociationFixture.coverage.diaryPrivacy))
        let todo = Fixture.todo(values: [ImageAssociationFixture.todo(), ImageAssociationFixture.todo(Fixture.otherID)], input: input)
        let routine = Fixture.routine(values: [ImageAssociationFixture.routine(), ImageAssociationFixture.routine(Fixture.otherID)], input: input)
        let diary = Fixture.diary(values: [ImageAssociationFixture.diary(), ImageAssociationFixture.diary(Fixture.otherID)], input: input)
        #expect(todo.matches.map(\.id.id) == [Fixture.id] && todo.undeterminedObjects.map(\.id) == [Fixture.otherID])
        #expect(routine.matches.map(\.id.id) == [Fixture.id] && routine.undeterminedObjects.map(\.id) == [Fixture.otherID])
        #expect(diary.matches.map(\.id.id) == [Fixture.id] && diary.undeterminedObjects.map(\.id) == [Fixture.otherID])
        #expect(!todo.isCompleteForCoveredTypes && !routine.isCompleteForCoveredTypes && !diary.isCompleteForCoveredTypes)
        #expect(todo.coverage.coveredTypes == [.todo] && todo.coverage.isPartialTypeCoverage)
    }

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func invalidCoverageAndUnknownProtectionRemainConservative(_ kind: AttachmentOwner) {
        let key = AttachmentOwnerKey(kind: kind, id: Fixture.id)
        var coverage = ImageAssociationFixture.coverage
        coverage.associations.objects[key] = .invalid
        let image = Fixture.image(kind)
        let invalid = Fixture.observe(kind, input: Fixture.input([image], coverage: coverage))
        #expect(invalid.matches.isEmpty && invalid.unknown.map(\.id) == [Fixture.id])
        #expect(invalid.issues.contains(.association(.invalidAssociationData)))
        coverage = ImageAssociationFixture.coverage
        coverage.imageIdentities.ids[image.id] = .invalid
        let invalidID = Fixture.observe(kind, input: Fixture.input([image], coverage: coverage))
        #expect(invalidID.issues.contains(.association(.invalidImageIdentity)) && !invalidID.complete)
        var protected = image
        protected.protection = .unknown
        let unknownProtection = Fixture.observe(kind, input: Fixture.input([protected]))
        #expect(unknownProtection.matches.isEmpty && unknownProtection.unknown.map(\.id) == [Fixture.id])
        #expect(unknownProtection.issues.contains(.protectedAssociation))
    }
}
