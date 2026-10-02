import Foundation
import Testing
@testable import AreaChain

struct ImageAssociationIdentityTests {
    private typealias Fixture = ImageAssociationFixture

    @Test func threeOwnersWithSameUUIDRemainDistinct() {
        let owners = ImageOwnerSnapshots(todos: [Fixture.todo()], routines: [Fixture.routine()], diaries: [Fixture.diary()])
        let keys = [AttachmentOwner.todo, .routine, .diary].map { AttachmentOwnerKey(kind: $0, id: Fixture.key.id) }
        let images = keys.map { Fixture.image(owner: $0) }
        let result = ImageAssociationReader.read(Fixture.request(images: images, owners: owners))
        #expect(result.images.map(\.id.id) == images.map(\.id))
        #expect(result.owners.count == 3)
        #expect(keys.allSatisfy { result.association(for: $0).presence == .present })
        #expect(result.owners[keys[0]]?.relatedObject == .init(type: .todo, id: Fixture.key.id))
        #expect(result.owners[keys[1]]?.relatedObject == .init(type: .routine, id: Fixture.key.id))
        #expect(result.owners[keys[2]]?.relatedObject == .init(type: .diary, id: Fixture.key.id))
        #expect(!Fixture.containsSecret(result))
    }

    @Test(arguments: [false, true]) func duplicateOwnersIncludeTombstones(deleted: Bool) {
        var other = Fixture.todo()
        if deleted { other.deletedAt = Fixture.date }
        let independent = Fixture.todo(UUID())
        let independentKey = AttachmentOwnerKey(kind: .todo, id: independent.id)
        let result = ImageAssociationReader.read(Fixture.request(
            images: [Fixture.image(), Fixture.image(owner: independentKey)],
            owners: .init(todos: [Fixture.todo(), other, independent], routines: [], diaries: [])))
        #expect(result.association(for: Fixture.key).ownerState == .ambiguous)
        #expect(result.association(for: Fixture.key).presence == .unknown)
        #expect(result.images.map(\.owner) == [independentKey])
        #expect(result.diagnostics.contains(.init(issue: .duplicateOwnerID, owner: Fixture.key)))
    }

    @Test(arguments: [false, true]) func duplicateImageIdentityIsQuarantined(deleted: Bool) {
        let image = Fixture.image()
        var duplicate = image
        if deleted { duplicate.deletedAt = Fixture.date }
        let result = ImageAssociationReader.read(Fixture.request(images: [image, duplicate]))
        #expect(result.images.isEmpty)
        #expect(result.association(for: Fixture.key).presence == .unknown)
        #expect(result.diagnostics.contains(.init(issue: .duplicateImageID, owner: Fixture.key)))
    }

    @Test func duplicateImagesAcrossOwnersDoNotBecomeActionable() {
        let image = Fixture.image()
        let routineKey = AttachmentOwnerKey(kind: .routine, id: Fixture.key.id)
        let duplicate = Fixture.image(owner: routineKey, id: image.id)
        let result = ImageAssociationReader.read(Fixture.request(images: [image, duplicate],
            owners: .init(todos: [Fixture.todo()], routines: [Fixture.routine()], diaries: [])))
        #expect(result.images.isEmpty)
        #expect(result.association(for: Fixture.key).presence == .unknown)
        #expect(result.association(for: routineKey).presence == .unknown)
    }

    @Test func wrongTypeDoesNotBorrowLiveUUID() {
        let wrong = AttachmentOwnerKey(kind: .routine, id: Fixture.key.id)
        let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image(owner: wrong)]))
        #expect(result.images.isEmpty)
        #expect(result.association(for: wrong).ownerState == .missing)
        #expect(result.diagnostics.contains(.init(issue: .missingOwner, owner: wrong)))
        #expect(result.association(for: Fixture.key).presence == .absent)
    }

    @Test func unknownKindTaintsOnlyPotentialOwners() {
        var image = Fixture.image()
        image.ownerKind = Fixture.secret
        let other = Fixture.todo(UUID())
        let otherKey = AttachmentOwnerKey(kind: .todo, id: other.id)
        let result = ImageAssociationReader.read(Fixture.request(images: [image],
            owners: .init(todos: [Fixture.todo(), other], routines: [], diaries: [])))
        #expect(result.association(for: Fixture.key).presence == .unknown)
        #expect(result.association(for: otherKey).presence == .absent)
        #expect(result.diagnostics.contains(.init(issue: .unknownOwnerKind, owner: Fixture.key)))
        #expect(!Fixture.containsSecret(result))
    }

    @Test func deletedImageAndOwnerHaveSeparateDiagnostics() {
        var image = Fixture.image()
        image.deletedAt = Fixture.date
        let result = ImageAssociationReader.read(Fixture.request(images: [image]))
        #expect(result.association(for: Fixture.key).presence == .absent)
        #expect(result.diagnostics.contains(.init(issue: .deletedImage, owner: Fixture.key)))
        var owner = Fixture.todo()
        owner.deletedAt = Fixture.date
        let deleted = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()],
            owners: .init(todos: [owner], routines: [], diaries: [])))
        #expect(deleted.association(for: Fixture.key).ownerState == .deleted)
        #expect(deleted.association(for: Fixture.key).presence == .unknown)
        #expect(deleted.images.isEmpty)
    }
}

extension ImageAssociationIdentityTests {
    @Test(arguments: [false, true]) func routineAndDiaryDuplicatesIncludeTombstones(deleted: Bool) {
        var routine = Fixture.routine()
        var diary = Fixture.diary()
        if deleted { routine.deletedAt = Fixture.date; diary.deletedAt = Fixture.date }
        let routineKey = AttachmentOwnerKey(kind: .routine, id: routine.id)
        let diaryKey = AttachmentOwnerKey(kind: .diary, id: diary.id)
        let result = ImageAssociationReader.read(Fixture.request(
            images: [Fixture.image(owner: routineKey), Fixture.image(owner: diaryKey)],
            owners: .init(todos: [], routines: [Fixture.routine(), routine], diaries: [Fixture.diary(), diary])))
        #expect(result.images.isEmpty)
        #expect(result.association(for: routineKey).ownerState == .ambiguous)
        #expect(result.association(for: diaryKey).ownerState == .ambiguous)
        #expect(result.association(for: routineKey).presence == .unknown)
        #expect(result.association(for: diaryKey).presence == .unknown)
    }

    @Test func unknownKindWithoutAnyOwnerStillReportsMachineDiagnostic() {
        var image = Fixture.image()
        image.ownerKind = Fixture.secret
        let result = ImageAssociationReader.read(Fixture.request(images: [image], owners: .init()))
        #expect(result.images.isEmpty)
        #expect(result.diagnostics.contains(.init(issue: .unknownOwnerKind, owner: nil)))
        #expect(!Fixture.containsSecret(result))
    }
}
