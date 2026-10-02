import Foundation
import Testing
@testable import AreaChain

struct ImageAssociationPrivacyTests {
    private typealias Fixture = ImageAssociationFixture

    @Test func protectedImagesNeverExposeNamesCountsOrProjection() {
        var image = Fixture.image()
        image.protection = .protected
        image.filename = Fixture.secret
        let one = ImageAssociationReader.read(Fixture.request(images: [image]))
        var unknown = Fixture.image()
        unknown.protection = .unknown
        let many = ImageAssociationReader.read(Fixture.request(images: [image, image, Fixture.image(), unknown]))
        #expect(one == many)
        #expect(one.association(for: Fixture.key).presence == .protected)
        #expect(one.association(for: Fixture.key).browse == .protected)
        #expect(one.images.isEmpty && one.owners.isEmpty)
        #expect(!Fixture.containsSecret(one))
    }

    @Test(arguments: ["flag", "marker", "tag", "privateTag", "unavailable"])
    func diaryProtectionUsesExistingProjection(source: String) {
        var diary = Fixture.diary()
        let tagID = UUID()
        var names: [UUID: String] = [:]
        var privateTags = Set<UUID>()
        switch source {
        case "flag": diary.isPrivate = true
        case "marker": diary.text += " #PASSWORD"
        case "tag": diary.tagIDs = tagID.uuidString; names[tagID] = "密码"
        case "privateTag": diary.tagIDs = tagID.uuidString; names[tagID] = "合成"; privateTags.insert(tagID)
        default: diary.isContentAvailable = false
        }
        let key = AttachmentOwnerKey(kind: .diary, id: diary.id)
        var image = Fixture.image(owner: key)
        image.filename = Fixture.secret
        let owners = ImageOwnerSnapshots(todos: [], routines: [], diaries: [diary])
        let privacy = DiaryQueryMetadata(tagNames: names, privateTagIDs: privateTags)
        let one = ImageAssociationReader.read(Fixture.request(images: [image], owners: owners, privacy: privacy))
        let empty = ImageAssociationReader.read(Fixture.request(images: [], owners: owners, privacy: privacy))
        image.protection = .unknown
        let unknown = ImageAssociationReader.read(Fixture.request(images: [image, image], owners: owners, privacy: privacy))
        #expect(one == empty)
        #expect(one == unknown)
        #expect(one.association(for: key).presence == .protected)
        #expect(one.images.isEmpty && one.owners.isEmpty)
        #expect(!Fixture.containsSecret(one))
    }

    @Test func insufficientPrivacyNeverDefaultsToPublic() {
        let key = AttachmentOwnerKey(kind: .diary, id: Fixture.key.id)
        let owners = ImageOwnerSnapshots(todos: [], routines: [], diaries: [Fixture.diary()])
        let metadata = [DiaryQueryMetadata(tagNames: nil, privateTagIDs: []),
                        DiaryQueryMetadata(tagNames: [:], privateTagIDs: nil)]
        for privacy in metadata {
            let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image(owner: key)], owners: owners, privacy: privacy))
            #expect(result.images.isEmpty)
            #expect(result.association(for: key).presence == .protected)
            #expect(result.diagnostics.contains(.init(issue: .privacyMetadataIncomplete, owner: key)))
        }
        var coverage = Fixture.coverage
        coverage.diaryPrivacy = .init(objects: [Fixture.key: .completeIncludingDeleted])
        let scoped = ImageAssociationReader.read(Fixture.request(images: [Fixture.image(owner: key)], owners: owners, coverage: coverage))
        #expect(scoped.images.isEmpty)
    }

    @Test func missingAssociatedTagAndMalformedTagsAreNotPublic() {
        var diary = Fixture.diary()
        let key = AttachmentOwnerKey(kind: .diary, id: diary.id)
        for raw in [UUID().uuidString, Fixture.secret] {
            diary.tagIDs = raw
            let result = ImageAssociationReader.read(Fixture.request(images: [Fixture.image(owner: key)],
                owners: .init(todos: [], routines: [], diaries: [diary])))
            #expect(result.images.isEmpty && result.owners.isEmpty)
            #expect(!Fixture.containsSecret(result))
        }
    }

    @Test func unknownImageProtectionCannotPublishAssociationTruth() {
        var image = Fixture.image()
        image.protection = .unknown
        image.filename = Fixture.secret
        let result = ImageAssociationReader.read(Fixture.request(images: [image]))
        #expect(result.association(for: Fixture.key).presence == .protected)
        #expect(result.association(for: Fixture.key).browse == .protected)
        #expect(result.images.isEmpty && result.owners.isEmpty)
        #expect(result.diagnostics.contains(.init(issue: .privacyMetadataIncomplete, owner: Fixture.key)))
        #expect(!Fixture.containsSecret(result))
    }

    @Test func descriptionsAndOwnerProjectionDoNotCopyFullContent() {
        var image = Fixture.image()
        image.filename = Fixture.secret
        let request = Fixture.request(images: [image])
        let result = ImageAssociationReader.read(request)
        #expect(!String(describing: request).contains(Fixture.secret))
        #expect(!String(reflecting: request).contains(Fixture.secret))
        #expect(!String(describing: request.images).contains(Fixture.secret))
        #expect(!String(reflecting: result).contains(Fixture.secret))
        #expect(!String(reflecting: result.images).contains(Fixture.secret))
        #expect(!Fixture.containsSecret(result.owners))
        #expect(result.images.first?.filename == Fixture.secret)
        guard case .todo(let attributes) = result.owners[Fixture.key]?.attributes else {
            Issue.record("缺少已核实所属任务投影")
            return
        }
        #expect(attributes.scheduledDay == "2026-10-01")
        #expect(attributes.createdAt == Fixture.date)
        #expect(!attributes.isDone)
    }
}
