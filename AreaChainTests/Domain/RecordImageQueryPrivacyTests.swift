import Foundation
import Testing
@testable import AreaChain

struct RecordImageQueryPrivacyTests {
    typealias Fixture = RecordImageQueryFixture

    @Test func readablePrivateBodyDoesNotAuthorizeImagePresence() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        diary.isPrivate = true
        let image = Fixture.image(.diary, id: diary.id)
        let request = DiaryQueryFixture.request(TodoQueryFixture.session("/diaries has:image"), [diary])
        var withImages = request
        withImages.imageInput = Fixture.input([image])
        let response = DiaryQueryProvider.read(withImages)
        #expect(diary.isContentAvailable)
        #expect(response.matches.isEmpty && response.undeterminedObjects.map(\.id) == [diary.id])
        #expect(response.diagnostics.map(\.issue) == [.imageAssociation(.protectedAssociation)])
        #expect(!DiaryQueryFixture.containsSecret(response))
        let oldText = DiaryQueryFixture.read("/diaries " + DiaryQueryFixture.secret, [diary])
        #expect(oldText.matches.count == 1)
        if case .hiddenTitle = oldText.matches.first?.presentation {} else { Issue.record("私密正文须隐藏") }
    }

    @Test func protectedZeroOneManyAndMalformedImagesHaveIdenticalPublicResponse() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        diary.isPrivate = true
        let session = TodoQueryFixture.session("/diaries has:image")
        var request = DiaryQueryFixture.request(session, [diary])
        request.imageInput = Fixture.input()
        let baseline = DiaryQueryProvider.read(request)
        var image = Fixture.image(.diary, id: diary.id)
        image.filename = DiaryQueryFixture.secret
        var malformed = image
        malformed.createdAt = Date(timeIntervalSince1970: .nan)
        malformed.protection = .unknown
        for images in [[image], [image, image], [image, malformed, image]] {
            request.imageInput = Fixture.input(images)
            let response = DiaryQueryProvider.read(request)
            #expect(response == baseline)
            #expect(!DiaryQueryFixture.containsSecret(response))
        }
    }

    @Test func incompletePrivacyStaysProtectedIndependentOfImageCount() {
        let diary = DiaryQueryFixture.diary()
        let session = TodoQueryFixture.session("/diaries has:image")
        for metadata in [DiaryQueryMetadata(tagNames: nil, privateTagIDs: []), .init(tagNames: [:], privateTagIDs: nil)] {
            var request = DiaryQueryFixture.request(session, [diary], metadata: metadata)
            request.imageInput = Fixture.input()
            let empty = DiaryQueryProvider.read(request)
            request.imageInput = Fixture.input([Fixture.image(.diary, id: diary.id)])
            #expect(DiaryQueryProvider.read(request) == empty)
            #expect(empty.diagnostics.contains { $0.issue == .imageAssociation(.protectedAssociation) })
            #expect(empty.undeterminedObjects.map(\.id) == [diary.id])
        }
        var coverage = ImageAssociationFixture.coverage
        coverage.diaryPrivacy.objects[.init(kind: .diary, id: diary.id)] = .partial
        let response = Fixture.diary(values: [diary], input: Fixture.input([], coverage: coverage))
        #expect(response.diagnostics.contains { $0.issue == .imageAssociation(.association(.privacyMetadataIncomplete)) })
        #expect(!response.isCompleteForCoveredTypes)
    }

    @Test func metadataHasOneAuthorityAndChangedSnapshotsRebuildAssociation() {
        var diary = DiaryQueryFixture.diary()
        diary.tagIDs = TodoQueryFixture.work.uuidString
        let source = "/diaries #工作 has:image"
        let input = Fixture.input([Fixture.image(.diary, id: diary.id)])
        let publicMetadata = DiaryQueryMetadata(tagNames: TodoQueryFixture.names, privateTagIDs: [])
        let privateMetadata = DiaryQueryMetadata(tagNames: TodoQueryFixture.names, privateTagIDs: [TodoQueryFixture.work])
        let publicResult = Fixture.diary(source, values: [diary], input: input, metadata: publicMetadata)
        #expect(publicResult.matches.map(\.id.id) == [diary.id])
        let privateResult = Fixture.diary(source, values: [diary], input: input, metadata: privateMetadata)
        #expect(privateResult.matches.isEmpty && privateResult.undeterminedObjects.map(\.id) == [diary.id])
        diary.isPrivate = true
        let changed = Fixture.diary(source, values: [diary], input: input, metadata: publicMetadata)
        #expect(changed.undeterminedObjects.map(\.id) == [diary.id])
        #expect(changed.requestID == publicResult.requestID)
    }

    @Test func noImageConditionPreservesDatesTagsAndHiddenEvidence() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        diary.isPrivate = true
        diary.tagIDs = TodoQueryFixture.work.uuidString
        let session = TodoQueryFixture.session("/diaries #合成工作 date:today " + DiaryQueryFixture.secret)
        var request = DiaryQueryFixture.request(session, [diary])
        let before = DiaryQueryProvider.read(request)
        var bad = Fixture.image(.diary, id: diary.id)
        bad.protection = .unknown
        request.imageInput = Fixture.input([bad, bad], coverage: .init())
        let after = DiaryQueryProvider.read(request)
        #expect(after == before && after.matches.count == 1)
        #expect(!DiaryQueryFixture.containsSecret(after))
        #expect(!after.matches[0].metadataEvidence.contains { $0.field == .diaryBody || $0.field == .imageAssociation })
    }

    @Test func falseConjunctRetainsProtectionDiagnosticWithoutAffectingResult() {
        var diary = DiaryQueryFixture.diary()
        diary.isPrivate = true
        let response = Fixture.diary("/diaries date:2020-01-01 has:image", values: [diary], input: Fixture.input())
        #expect(response.matches.isEmpty && response.undeterminedObjects.isEmpty && response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains {
            $0.issue == .imageAssociation(.protectedAssociation) && !$0.affectsDetermination && $0.severity == .warning
        })
    }
}
