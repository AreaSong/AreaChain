import Foundation
import Testing
@testable import AreaChain

struct ImageQueryBoundaryTests {
    @Test func typesPreserveOwnerBranchesAndKeepCreatedSeparate() throws {
        let session = TodoQueryFixture.session("/images status:open")
        let image = try #require(session.typeAnalysis.assessment(for: .image))
        #expect(image.isPossible && !image.requiresInput)
        #expect(image.imageOwnerAssessments.first { $0.type == .todo }?.isPossible == true)
        #expect(image.imageOwnerAssessments.first { $0.type == .routine }?.requiresInput == true)
        #expect(image.imageOwnerAssessments.first { $0.type == .diary }?.isPossible == false)
        for query in ["date:today created:2023-11-15", "on:today created:2023-11-15", "on:today status:skipped"] {
            #expect(TodoQueryFixture.session("/images " + query).typeAnalysis.possibleTypes == [.image])
        }
        for query in ["status:open status:done", "on:today date:2026-10-02", "date:today date:2026-10-02"] {
            #expect(TodoQueryFixture.session("/images " + query).typeAnalysis.possibleTypes.isEmpty)
        }
        #expect(ImageQueryFixture.read("/images status:skipped").state == .requiresInput)
    }

    @Test func imageItselfCannotSatisfyHasImageAndOtherProvidersRemainUnwired() {
        let result = ImageQueryFixture.read("/images has:image")
        #expect(result.state == .inapplicableConditions && result.matches.isEmpty)
        #expect(result.typeAnalysis.assessment(for: .image)?.reasons.contains { $0.issue == .fieldNotApplicable } == true)
        let todo = TodoQueryFixture.read("/tasks has:image", [TodoQueryFixture.todo(1)])
        #expect(todo.diagnostics.contains { $0.issue == .imageAssociationUnavailable })
        for source in ["/tasks photo", "/trash photo", "/clipboard photo", "/diaries photo"] {
            #expect(ImageQueryFixture.read(source).state == .notApplicable)
        }
    }

    @Test func deletedDuplicateMissingAndUnknownProtectionFollowAssociationReader() {
        var images = ImageQueryFixture.images
        images[0].deletedAt = ImageAssociationFixture.date
        images.append(images[1])
        let association = ImageQueryFixture.association(images: images)
        let raw = ImageAssociationReader.read(association)
        let response = ImageQueryFixture.read("/images photo", association: association)
        #expect(response.matches.map(\.id) == raw.images.map(\.id))
        #expect(response.associationDiagnostics == raw.diagnostics && response.associations == raw.associations)
        #expect(response.coverage.associations == .incomplete && !response.isCompleteForCoveredTypes)
        var owners = ImageQueryFixture.owners
        owners.todos = []
        owners.routines = nil
        images = ImageQueryFixture.images
        images[2].protection = .unknown
        let invalid = ImageQueryFixture.read("/images", association: ImageQueryFixture.association(images: images, owners: owners))
        #expect(invalid.matches.isEmpty && invalid.undeterminedObjects.isEmpty)
        #expect(invalid.associationDiagnostics.contains { $0.issue == .missingOwner })
        #expect(invalid.associationDiagnostics.contains { $0.issue == .ownerNotProvided })
        #expect(invalid.coverage.containsProtectedContent)
    }

    @Test func missingOwnerAttributesOnlyBlockConditionsThatNeedThem() {
        var owners = ImageQueryFixture.owners
        owners.todos?[0].dayKey = "invalid"
        let association = ImageQueryFixture.association(owners: owners)
        let filename = ImageQueryFixture.read("/images photo", association: association)
        #expect(filename.matches.count == 3 && filename.isCompleteForCoveredTypes)
        #expect(filename.owners[ImageAssociationFixture.key] == nil)
        let date = ImageQueryFixture.read("/images photo date:today", association: association)
        #expect(date.matches.map(\.owner.kind) == [.diary] && date.undeterminedObjects.count == 2)
        #expect(date.diagnostics.contains { $0.issue == .missingOwnerAttributes && $0.owner?.kind == .todo })
        let miss = ImageQueryFixture.read("/images absent date:today", association: association)
        #expect(miss.undeterminedObjects.isEmpty && miss.isCompleteForCoveredTypes)
    }

    @Test func emptyMissingAndPartialAssociationsAreNotCompleteZeroResults() {
        let missing = ImageQueryFixture.read("/images", association: ImageQueryFixture.association(images: nil))
        #expect(missing.matches.isEmpty && missing.coverage.associations == .incomplete && !missing.isCompleteForCoveredTypes)
        let empty = ImageQueryFixture.read("/images", association: ImageQueryFixture.association(images: []))
        #expect(empty.matches.isEmpty && empty.isCompleteForCoveredTypes)
        var coverage = ImageAssociationFixture.coverage
        coverage.associations.objects[ImageAssociationFixture.key] = .partial
        let partial = ImageQueryFixture.read("/images photo", association: ImageQueryFixture.association(coverage: coverage))
        #expect(partial.matches.count == 3 && !partial.isCompleteForCoveredTypes)
        #expect(partial.coverage.associations == .incomplete && partial.undeterminedObjects.isEmpty)
        let global = ImageQueryFixture.read("photo")
        #expect(global.matches.count == 3 && global.coverage.coveredTypes == [.image] && global.coverage.isPartialTypeCoverage)
    }
}
