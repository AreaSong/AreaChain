import Foundation
import Testing
@testable import AreaChain

struct ImageAssociationCoverageTests {
    private typealias Fixture = ImageAssociationFixture

    @Test func completeEmptyAndNotProvidedAreDifferent() {
        let empty = ImageAssociationReader.read(Fixture.request())
        let missing = ImageAssociationReader.read(Fixture.request(images: nil))
        #expect(empty.association(for: Fixture.key).presence == .absent)
        #expect(empty.association(for: Fixture.key).browse == .unavailable)
        #expect(missing.association(for: Fixture.key).presence == .unknown)
        #expect(missing.diagnostics.contains(.init(issue: .imagesNotProvided, owner: Fixture.key)))
        let noOwners = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()], owners: .init()))
        #expect(noOwners.association(for: Fixture.key).ownerState == .unknown)
        let emptyOwners = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()],
            owners: .init(todos: [], routines: [], diaries: [])))
        #expect(emptyOwners.association(for: Fixture.key).ownerState == .missing)
    }

    @Test func objectCoverageNeverPromotesOtherObjectsOrTypes() {
        let other = Fixture.todo(UUID())
        let otherKey = AttachmentOwnerKey(kind: .todo, id: other.id)
        let routineKey = AttachmentOwnerKey(kind: .routine, id: Fixture.key.id)
        var coverage = Fixture.coverage
        coverage.associations = .init(objects: [Fixture.key: .completeIncludingDeleted])
        let result = ImageAssociationReader.read(Fixture.request(
            owners: .init(todos: [Fixture.todo(), other], routines: [Fixture.routine()], diaries: []), coverage: coverage))
        #expect(result.association(for: Fixture.key).presence == .absent)
        #expect(result.association(for: otherKey).presence == .unknown)
        #expect(result.association(for: routineKey).presence == .unknown)
        #expect(result.association(for: .init(kind: .todo, id: UUID())).presence == .unknown)
    }

    @Test func partialAssociationCanStillProvePresence() {
        var coverage = Fixture.coverage
        coverage.associations = .init()
        let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()], coverage: coverage))
        #expect(result.association(for: Fixture.key).presence == .present)
        #expect(result.association(for: Fixture.key).browse == .available)
        #expect(result.diagnostics.contains(.init(issue: .associationCoverageIncomplete, owner: Fixture.key)))
    }

    @Test func perOwnerEnumerationDoesNotProveGlobalImageIdentity() {
        var coverage = Fixture.coverage
        coverage.imageIdentities = .init()
        let image = Fixture.image()
        let unknown = ImageAssociationReader.read(Fixture.request(images: [image], coverage: coverage))
        #expect(unknown.images.isEmpty)
        #expect(unknown.association(for: Fixture.key).presence == .unknown)
        coverage.imageIdentities.ids[image.id] = .completeIncludingDeleted
        let known = ImageAssociationReader.read(Fixture.request(images: [image], coverage: coverage))
        #expect(known.images.count == 1)
    }

    @Test(arguments: [ImageReadCompleteness.notProvided, .partial, .invalid])
    func incompleteOwnerIdentityDoesNotProduceDefiniteAssociation(state: ImageReadCompleteness) {
        var coverage = Fixture.coverage
        coverage.owners.objects[Fixture.key] = state
        let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()], coverage: coverage))
        #expect(result.images.isEmpty)
        #expect(result.association(for: Fixture.key).presence == .unknown)
    }

    @Test func ambiguityDoesNotEraseIndependentExistenceEvidence() {
        let duplicate = Fixture.image()
        let valid = Fixture.image()
        let result = ImageAssociationReader.read(Fixture.request(images: [duplicate, duplicate, valid]))
        #expect(result.association(for: Fixture.key).presence == .present)
        #expect(result.images.map(\.id.id) == [valid.id])
        #expect(result.diagnostics.contains(.init(issue: .duplicateImageID, owner: Fixture.key)))
    }

    @Test func invalidMetadataDoesNotEraseAssociationOrBecomeBrowsable() {
        var image = Fixture.image()
        image.createdAt = Date(timeIntervalSince1970: .nan)
        let result = ImageAssociationReader.read(Fixture.request(images: [image]))
        #expect(result.association(for: Fixture.key).presence == .present)
        #expect(result.images.isEmpty)
        #expect(result.diagnostics.contains(.init(issue: .invalidImageMetadata, owner: Fixture.key)))
    }
}

extension ImageAssociationCoverageTests {
    @Test func invalidAssociationScopeIsLocalAndCannotProvePresence() {
        let other = Fixture.todo(UUID())
        let key = AttachmentOwnerKey(kind: .todo, id: other.id)
        var coverage = Fixture.coverage
        coverage.associations.objects[Fixture.key] = .invalid
        let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image(), Fixture.image(owner: key)],
            owners: .init(todos: [Fixture.todo(), other], routines: [], diaries: []), coverage: coverage))
        #expect(result.association(for: Fixture.key).presence == .unknown)
        #expect(result.images.map(\.owner) == [key])
    }

    @Test func missingOwnerIsDistinguishedFromIncompleteOwnerLookup() {
        var coverage = Fixture.coverage
        coverage.owners.objects[Fixture.key] = .partial
        let owners = ImageOwnerSnapshots(todos: [], routines: [], diaries: [])
        let partial = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()], owners: owners, coverage: coverage))
        let complete = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()], owners: owners))
        #expect(partial.association(for: Fixture.key).ownerState == .unknown)
        #expect(!partial.diagnostics.contains(.init(issue: .missingOwner, owner: Fixture.key)))
        #expect(complete.association(for: Fixture.key).ownerState == .missing)
    }
}

extension ImageAssociationCoverageTests {
    @Test func invalidOwnerAttributesDoNotEraseValidTypedAssociation() {
        var todo = Fixture.todo()
        todo.dayKey = "2026-02-30"
        todo.tagIDs = Fixture.secret
        let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image()],
            owners: .init(todos: [todo], routines: [], diaries: [])))
        #expect(result.association(for: Fixture.key).presence == .present)
        #expect(result.owners[Fixture.key] == nil)
        #expect(result.images.map(\.owner) == [Fixture.key])
        #expect(result.diagnostics.contains(.init(issue: .invalidOwnerAttributes, owner: Fixture.key)))
        #expect(!Fixture.containsSecret(result))
    }
}
