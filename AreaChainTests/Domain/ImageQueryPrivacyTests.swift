import Foundation
import Testing
@testable import AreaChain

struct ImageQueryPrivacyTests {
    @Test func protectedImagesNeverEnterResultsDiagnosticsOrStoredEvidence() {
        var owners = ImageQueryFixture.owners
        owners.diaries?[0].isPrivate = true
        var images = ImageQueryFixture.images
        let hiddenID = images[2].id
        images[2].filename = ImageAssociationFixture.secret
        let association = ImageQueryFixture.association(images: images, owners: owners)
        let response = ImageQueryFixture.read("/images", association: association)
        #expect(response.matches.map(\.owner.kind) == [.todo, .routine])
        #expect(response.coverage.containsProtectedContent && !response.isCompleteForCoveredTypes)
        #expect(response.undeterminedObjects.isEmpty)
        #expect(!ImageAssociationFixture.containsSecret(response))
        #expect(!containsID(response, id: hiddenID))
        let request = ImageQueryFixture.request("/images " + ImageAssociationFixture.secret, association: association)
        #expect(!String(describing: request).contains(ImageAssociationFixture.secret))
        #expect(!String(reflecting: request).contains(ImageAssociationFixture.secret))
        #expect(!String(reflecting: response).contains(ImageQueryFixture.filename))
        #expect(response.matches.allSatisfy { !String(reflecting: $0).contains(ImageQueryFixture.filename) })
    }

    @Test func hiddenZeroOneManyDuplicatesAndPositionsProduceSamePublicResponse() {
        var owners = ImageQueryFixture.owners
        owners.diaries?[0].isPrivate = true
        var hidden = ImageQueryFixture.images[2]
        hidden.filename = ImageAssociationFixture.secret
        hidden.protection = .protected
        let publicImages = Array(ImageQueryFixture.images.prefix(2))
        let baseline = ImageQueryFixture.read("/images photo", association: ImageQueryFixture.association(images: publicImages, owners: owners))
        for images in [[hidden] + publicImages, publicImages + [hidden, hidden], [hidden, publicImages[0], hidden, publicImages[1]]] {
            let response = ImageQueryFixture.read("/images photo", association: ImageQueryFixture.association(images: images, owners: owners))
            #expect(response == baseline)
        }
    }

    @Test func publicMatchesUnknownHistoryAndProtectionCoexist() {
        var owners = ImageQueryFixture.owners
        owners.diaries?[0].isContentAvailable = false
        let response = ImageQueryFixture.read("/images photo date:today", association: ImageQueryFixture.association(owners: owners))
        #expect(response.state == .evaluated && response.matches.map(\.owner.kind) == [.todo])
        #expect(response.undeterminedObjects == [.init(type: .image, id: ImageQueryFixture.images[1].id)])
        #expect(response.coverage.containsProtectedContent && !response.isCompleteForCoveredTypes)
        #expect(!containsID(response, id: ImageQueryFixture.images[2].id))
    }

    @Test func unknownProtectionAndMixedProtectedOwnerDoNotPublishSiblingImages() {
        var images = ImageQueryFixture.images
        images[0].protection = .unknown
        var sibling = ImageAssociationFixture.image()
        sibling.filename = ImageAssociationFixture.secret
        images.append(sibling)
        let response = ImageQueryFixture.read("/images", association: ImageQueryFixture.association(images: images))
        #expect(response.matches.map(\.owner.kind) == [.routine, .diary])
        #expect(response.coverage.containsProtectedContent && response.undeterminedObjects.isEmpty)
        #expect(!containsID(response, id: sibling.id) && !containsID(response, id: images[0].id))
        #expect(response.associationDiagnostics.contains { $0.issue == .privacyMetadataIncomplete })
    }

    @Test func untypedProtectedInputCannotClaimCompleteZeroResults() {
        var hidden = ImageAssociationFixture.image(owner: .init(kind: .todo, id: UUID()))
        hidden.ownerKind = "unsupported-synthetic-kind"
        hidden.protection = .protected
        hidden.filename = ImageAssociationFixture.secret
        let emptyOwners = ImageOwnerSnapshots(todos: [], routines: [], diaries: [])
        let response = ImageQueryFixture.read("/images", association: ImageQueryFixture.association(images: [hidden], owners: emptyOwners))
        #expect(response.matches.isEmpty && response.undeterminedObjects.isEmpty)
        #expect(response.coverage.associations == .incomplete && !response.isCompleteForCoveredTypes)
        #expect(response.associationDiagnostics.isEmpty && response.diagnostics.isEmpty)
        #expect(!containsID(response, id: hidden.id) && !ImageAssociationFixture.containsSecret(response))
    }

    private func containsID(_ value: Any, id: UUID) -> Bool {
        if let value = value as? UUID { return value == id }
        return Mirror(reflecting: value).children.contains { containsID($0.value, id: id) }
    }
}
