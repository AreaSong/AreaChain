import Foundation
import Testing
@testable import AreaChain

struct TrashTombstonePrivacyTests {
    private typealias Fixture = TrashFixture

    @Test func privateDiaryZeroOneManyAndMalformedImagesHaveIdenticalPublicProjection() {
        var input = Fixture.input()
        var diary = Fixture.diary()
        diary.isPrivate = true
        diary.text = "synthetic-private-body"
        input.diaries = [diary]
        let baseline = TrashTombstoneReader.read(input)
        var image = Fixture.image(owner: .diary)
        image.filename = "synthetic-private-filename.png"
        for images in [[image], [image, image], [image, Fixture.image(Fixture.otherID, owner: .diary)]] {
            input.images = images
            #expect(TrashTombstoneReader.read(input) == baseline)
        }
        image.deletedAt = Date(timeIntervalSince1970: .nan)
        input.images = [image]
        #expect(TrashTombstoneReader.read(input) == baseline)
        #expect(baseline.visibleTopLevelCount == 1)
        #expect(baseline.visibleMemberCount == 0)
        #expect(baseline.groups[0].imageRead == .displayLimited)
        #expect(!storedStrings(baseline).contains("synthetic-private-body"))
        #expect(!storedStrings(TrashTombstoneReader.read(input)).contains("synthetic-private-filename.png"))
    }

    @Test func incompletePrivacyNeverDefaultsToPublic() throws {
        var input = Fixture.input()
        input.diaries = [Fixture.diary()]
        input.images = [Fixture.image(owner: .diary)]
        input.privacy = .init(tagNames: nil, privateTagIDs: nil)
        var result = TrashTombstoneReader.read(input)
        #expect(result.objects.count == 1)
        #expect(result.diagnostics.contains { $0.issue == .privacyMetadataIncomplete })
        let diary = try #require(result.objects.first)
        guard case .diary(let fields) = diary.fields else { Issue.record("expected diary"); return }
        #expect(fields.presentation == .hiddenTitle(L10n.string("diary.private.title", locale: input.locale)))
        input.privacy = .init(tagNames: [:], privateTagIDs: [])
        input.coverage.diaryPrivacy.types[.diary] = .partial
        result = TrashTombstoneReader.read(input)
        #expect(result.objects.count == 1)
        #expect(result.diagnostics.contains { $0.issue == .privacyMetadataIncomplete })
        #expect(!storedStrings(result).contains("合成正文"))
    }

    @Test func unreadableAndDeletedPrivateTagMetadataRemainProtected() {
        var input = Fixture.input()
        var diary = Fixture.diary()
        diary.tagIDs = Fixture.otherID.uuidString
        input.diaries = [diary]
        input.images = [Fixture.image(owner: .diary)]
        input.privacy = .init(tagNames: [Fixture.otherID: "保护标签"], privateTagIDs: [Fixture.otherID])
        input.tags = [.init(id: Fixture.otherID, name: "保护标签", deletedAt: Fixture.date, isPrivateDiary: true)]
        #expect(!TrashTombstoneReader.read(input).objects.contains { $0.id.type == .image })
        diary.tagIDs = ""
        diary.text = "synthetic-unreadable-placeholder"
        diary.isContentAvailable = false
        input.diaries = [diary]
        let unreadable = TrashTombstoneReader.read(input)
        #expect(!storedStrings(unreadable).contains("synthetic-unreadable-placeholder"))
        #expect(!unreadable.objects.contains { $0.id.type == .image })
    }

    @Test func legacyPrivateMarkerDoesNotEnterGroupSummary() {
        var input = Fixture.input()
        var diary = Fixture.diary()
        diary.text = "#password synthetic-secret"
        input.diaries = [diary]
        input.images = [Fixture.image(owner: .diary)]
        let result = TrashTombstoneReader.read(input)
        #expect(!result.objects.contains { $0.id.type == .image })
        #expect(!storedStrings(result).contains("#password synthetic-secret"))
    }

    @Test func unknownAndProtectedImageMetadataSuppressMixedOwnerDetails() {
        for protection in [ImageProtection.unknown, .protected] {
            var input = Fixture.family()
            input.images?[0].protection = protection
            let baseline = TrashTombstoneReader.read(input)
            input.images?.append(Fixture.image(Fixture.otherID))
            let mixed = TrashTombstoneReader.read(input)
            #expect(mixed == baseline)
            #expect(!mixed.objects.contains { $0.id.type == .image })
            #expect(!mixed.diagnostics.contains { $0.object?.type == .image })
            #expect(mixed.visibleMemberCount == 1)
        }
    }

    @Test func protectedDuplicateCannotLeakThroughPublicOwnerOrCoverageTable() {
        var input = Fixture.family()
        var privateImage = Fixture.image(owner: .diary)
        privateImage.protection = .protected
        input.images?.append(privateImage)
        input.coverage.objects[Fixture.ref(.image, Fixture.imageID)] = .completeIncludingDeleted
        let result = TrashTombstoneReader.read(input)
        #expect(!result.objects.contains { $0.id.type == .image })
        #expect(!result.diagnostics.contains { $0.object?.type == .image })
        #expect(!storedStrings(result).contains(Fixture.imageID.uuidString))
    }

    @Test func missingDiaryOwnerHidesImageEvenWhenAnotherTypeHasSameUUID() {
        var input = Fixture.family()
        input.images = [Fixture.image(owner: .diary)]
        let result = TrashTombstoneReader.read(input)
        #expect(!result.objects.contains { $0.id.type == .image })
        #expect(!result.diagnostics.contains { $0.object?.type == .image })
    }

    @Test func descriptionsAreRedactedAtEveryPublicValueBoundary() {
        let input = Fixture.family()
        let output = TrashTombstoneReader.read(input)
        #expect(String(describing: input) == "TrashTombstoneInput(redacted)")
        #expect(String(reflecting: input) == "TrashTombstoneInput(redacted)")
        #expect(String(reflecting: output) == "TrashTombstoneResponse(redacted)")
        for object in output.objects {
            #expect(String(describing: object) == "TrashTombstone(redacted)")
            #expect(String(reflecting: object.fields) == "TrashObjectFields(redacted)")
        }
        #expect(String(reflecting: output.groups[0]) == "TrashTombstoneGroup(redacted)")
    }

    private func storedStrings(_ value: Any) -> Set<String> {
        if let string = value as? String { return [string] }
        if let id = value as? UUID { return [id.uuidString] }
        return Mirror(reflecting: value).children.reduce(into: Set<String>()) { result, child in
            result.formUnion(storedStrings(child.value))
        }
    }
}
