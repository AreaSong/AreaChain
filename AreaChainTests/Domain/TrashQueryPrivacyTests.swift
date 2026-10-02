import Foundation
import Testing
@testable import AreaChain

struct TrashQueryPrivacyTests {
    @Test func hiddenTitleIsNotBodyAndNegationRemainsUnknown() {
        var input = TrashFixture.input()
        var diary = TrashFixture.diary()
        diary.isPrivate = true
        diary.text = "synthetic-hidden-body"
        input.diaries = [diary]
        for query in ["synthetic-hidden-body", "-absent", L10n.string("diary.private.title", locale: input.locale)] {
            let result = TrashQueryFixture.read("/trash \(query)", input)
            #expect(result.matches.isEmpty)
            #expect(result.undeterminedObjects == [TrashFixture.ref(.diary)])
            #expect(!TrashQueryFixture.strings(result).contains("synthetic-hidden-body"))
        }
        let date = TrashQueryFixture.read("/trash date:2026-10-02", input)
        #expect(date.definiteMatchCount == 1)
        let no = TrashQueryFixture.read("/trash absent date:2026-10-03", input)
        #expect(no.undeterminedObjects.isEmpty && no.nonmatchingObjects == [TrashFixture.ref(.diary)])
        #expect(no.diagnostics.allSatisfy { !$0.affectsDetermination })
    }

    @Test func incompletePrivacyAndUnavailableBodyCannotBeReadBack() {
        for mode in 0..<3 {
            var input = TrashFixture.input()
            var diary = TrashFixture.diary()
            diary.text = "synthetic-unreadable"
            if mode == 0 { diary.isContentAvailable = false }
            if mode == 1 { input.privacy = .init(tagNames: [:], privateTagIDs: nil) }
            if mode == 2 { input.coverage.diaryPrivacy.types[.diary] = .partial }
            input.diaries = [diary]
            let result = TrashQueryFixture.read("/trash", input)
            #expect(result.definiteMatchCount == 1)
            #expect(!TrashQueryFixture.strings(result).contains("synthetic-unreadable"))
            #expect(TrashQueryFixture.read("/trash synthetic-unreadable", input).undeterminedObjects.count == 1)
        }
    }

    @Test func protectedImagesNeverLeakThroughHitsContextsDiagnosticsOrCounts() {
        var input = TrashFixture.input()
        var diary = TrashFixture.diary()
        diary.isPrivate = true
        input.diaries = [diary]
        for source in ["/trash", "/trash synthetic", "/trash date:2026-10-02", "/trash has:image"] {
            input.images = []
            let baseline = TrashQueryFixture.read(source, input)
            var image = TrashFixture.image(owner: .diary)
            image.filename = "synthetic-hidden-filename.png"
            for images in [[image], [image, image], [image, TrashFixture.image(TrashFixture.otherID, owner: .diary)]] {
                input.images = images
                let result = TrashQueryFixture.read(source, input)
                #expect(result.matches == baseline.matches && result.groups == baseline.groups)
                #expect(result.diagnostics == baseline.diagnostics && result.readingDiagnostics == baseline.readingDiagnostics)
                #expect(result.undeterminedObjects == baseline.undeterminedObjects)
                #expect(result.definiteMatchCount == baseline.definiteMatchCount)
                #expect(result.visibleContextCount == baseline.visibleContextCount && result.imageDisplayLimited)
                #expect(!TrashQueryFixture.strings(result).contains(TrashFixture.imageID.uuidString))
                #expect(!TrashQueryFixture.strings(result).contains(image.filename))
            }
        }
    }

    @Test func unknownProtectionAndCrossOwnerDuplicatesAreNotPromoted() {
        var input = TrashFixture.family()
        for protection in [ImageProtection.protected, .unknown] {
            input.images?[0].protection = protection
            let result = TrashQueryFixture.read("/trash synthetic", input)
            #expect(result.matches.isEmpty && result.undeterminedObjects.isEmpty)
            #expect(result.readingDiagnostics.isEmpty)
            #expect(!TrashQueryFixture.strings(result).contains(TrashFixture.imageID.uuidString))
        }
    }

    @Test func debugDescriptionsAreRedacted() {
        let session = TodoQueryFixture.session("/trash synthetic-query")
        let request = TrashQueryRequest(requestID: UUID(), session: session, input: TrashQueryFixture.all())
        let result = TrashQueryProvider.read(request)
        #expect(String(reflecting: request) == "TrashQueryRequest(redacted)")
        #expect(String(reflecting: result) == "TrashQueryResponse(redacted)")
        let all = TrashQueryFixture.read("/trash")
        #expect(all.matches.allSatisfy { String(reflecting: $0) == "TrashQueryMatch(redacted)" })
        #expect(all.groups.allSatisfy { String(reflecting: $0) == "TrashQueryGroup(redacted)" })
    }
}
