import Foundation
import Testing
@testable import AreaChain

struct DiaryQueryPrivacyTests {
    @Test func hiddenMetadataEvidenceCannotRevealWhichTextExclusionAlternativeHeld() {
        var first = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        first.isPrivate = true
        var second = first
        second.text += " 咖啡"
        let source = "/diaries (-咖啡 | " + DiaryQueryFixture.secret + ")"
        let left = DiaryQueryFixture.read(source, [first])
        let right = DiaryQueryFixture.read(source, [second])
        #expect(left.matches.count == 1 && right.matches.count == 1)
        #expect(left == right)
        #expect(left.matches[0].metadataEvidence.allSatisfy { $0.field == .scope })
    }

    @Test func missingMetadataDiagnosticsDoNotRevealLegacyBodyMarkers() {
        let first = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        var second = first
        second.text += " #password"
        let metadata = DiaryQueryMetadata(tagNames: nil, privateTagIDs: nil)
        let source = "/diaries " + DiaryQueryFixture.secret
        let left = DiaryQueryFixture.read(source, [first], metadata: metadata)
        let right = DiaryQueryFixture.read(source, [second], metadata: metadata)
        #expect(left.matches.count == 1 && right.matches.count == 1)
        #expect(left == right)
    }

    @Test func allExistingSensitiveSourcesHideReadableBody() throws {
        var flagged = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        flagged.isPrivate = true
        var privateTag = DiaryQueryFixture.diary(2, text: DiaryQueryFixture.secret)
        privateTag.tagIDs = TodoQueryFixture.work.uuidString
        var passwordTag = DiaryQueryFixture.diary(3, text: DiaryQueryFixture.secret)
        passwordTag.tagIDs = TodoQueryFixture.study.uuidString
        let englishMarker = DiaryQueryFixture.diary(4, text: DiaryQueryFixture.secret + " #PaSsWoRd")
        let chineseMarker = DiaryQueryFixture.diary(5, text: DiaryQueryFixture.secret + " #密码")
        let metadata = DiaryQueryMetadata(tagNames: [TodoQueryFixture.work: "工作", TodoQueryFixture.study: "password"],
                                          privateTagIDs: [TodoQueryFixture.work])
        let rows = [flagged, privateTag, passwordTag, englishMarker, chineseMarker]
        #expect(rows.allSatisfy { DiaryPrivacy.isSensitive($0, tagNames: metadata.tagNames!, privateTagIDs: metadata.privateTagIDs!) })
        let result = DiaryQueryFixture.read("/diaries " + DiaryQueryFixture.secret, rows, metadata: metadata)
        #expect(result.matches.count == rows.count)
        #expect(result.matches.allSatisfy {
            $0.presentation == .hiddenTitle(L10n.string("diary.private.title", locale: DiaryQueryFixture.locale))
        })
        #expect(result.matches.allSatisfy { !$0.metadataEvidence.contains { $0.field == .diaryBody } })
        let leaked = DiaryQueryFixture.containsSecret(result)
        #expect(!leaked)
    }

    @Test func missingPrivacyFactsNeverDefaultToPublic() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        diary.tagIDs = TodoQueryFixture.work.uuidString
        let cases: [DiaryQueryMetadata] = [
            .init(tagNames: nil, privateTagIDs: nil), .init(tagNames: DiaryQueryFixture.names, privateTagIDs: nil),
            .init(tagNames: nil, privateTagIDs: []), .init(tagNames: [:], privateTagIDs: []),
            .init(tagNames: [:], privateTagIDs: [TodoQueryFixture.work])
        ]
        for metadata in cases {
            let result = DiaryQueryFixture.read("/diaries date:today", [diary], metadata: metadata)
            #expect(result.matches.count == 1 && result.isCompleteForCoveredTypes)
            #expect(result.diagnostics.contains { $0.issue == .incompletePrivacyMetadata && !$0.affectsDetermination })
            let leaked = DiaryQueryFixture.containsSecret(result)
            #expect(!leaked)
        }
        let explicitEmpty = DiaryQueryFixture.read("/diaries", [DiaryQueryFixture.diary()],
                                                  metadata: .init(tagNames: [:], privateTagIDs: []))
        #expect(explicitEmpty.diagnostics.isEmpty)
        guard case .publicText = explicitEmpty.matches.first?.presentation else { Issue.record("完整空资料应允许公开"); return }
    }

    @Test func privateResultsHaveNoBodyLengthRangeOrAlternativeDerivedDisplay() {
        var first = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret + " 第一种内容")
        first.isPrivate = true
        var second = first
        second.text = "更长的前缀 " + DiaryQueryFixture.secret + " 另一个后缀正文"
        let query = "/diaries (" + DiaryQueryFixture.secret + " | 第一种内容)"
        let left = DiaryQueryFixture.read(query, [first])
        let right = DiaryQueryFixture.read(query, [second])
        #expect(left.matches.count == 1 && right.matches.count == 1)
        #expect(left == right)
        let leaked = DiaryQueryFixture.containsSecret(left)
        #expect(!leaked)
    }

    @Test func descriptionsDiagnosticsAndNestedResultValuesDoNotLeak() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret + " #password")
        diary.tagIDs = TodoQueryFixture.work.uuidString
        let metadata = DiaryQueryMetadata(tagNames: nil, privateTagIDs: nil)
        let session = TodoQueryFixture.session("/diaries " + DiaryQueryFixture.secret)
        let request = DiaryQueryFixture.request(session, [diary], metadata: metadata)
        let response = DiaryQueryProvider.read(request)
        let descriptions = [String(describing: request), String(reflecting: request),
                            String(describing: response), String(reflecting: response),
                            String(describing: response.matches), String(reflecting: response.matches),
                            String(describing: response.diagnostics), String(reflecting: response.diagnostics)]
        let leaked = descriptions.contains { $0.contains(DiaryQueryFixture.secret) }
            || DiaryQueryFixture.containsSecret(response)
        #expect(!leaked)
        #expect(response.matches.count == 1)
    }

    @Test func unreadableUnflaggedSnapshotIsMaskedAndLocaleUsesExistingTitle() {
        var diary = DiaryQueryFixture.diary(text: DiaryQueryFixture.secret)
        diary.isContentAvailable = false
        for language in ["en", "zh-Hans"] {
            let locale = Locale(identifier: language)
            let request = DiaryQueryFixture.request(TodoQueryFixture.session("/diaries date:today"), [diary], locale: locale)
            let response = DiaryQueryProvider.read(request)
            #expect(response.matches.first?.presentation == .hiddenTitle(L10n.string("diary.private.title", locale: locale)))
            #expect(response.isCompleteForCoveredTypes)
            let leaked = DiaryQueryFixture.containsSecret(response)
            #expect(!leaked)
        }
    }

    @Test func safetyDiagnosticsSurviveDefiniteTextFailureAndDuplicateIdentity() {
        let diary = DiaryQueryFixture.diary(text: "普通正文")
        let metadata = DiaryQueryMetadata(tagNames: nil, privateTagIDs: nil)
        let miss = DiaryQueryFixture.read("/diaries 不存在", [diary], metadata: metadata)
        #expect(miss.matches.isEmpty && miss.isCompleteForCoveredTypes)
        #expect(miss.diagnostics.contains { $0.issue == .incompletePrivacyMetadata })
        let duplicate = DiaryQueryFixture.read("/diaries 不存在", [diary, diary], metadata: metadata)
        #expect(duplicate.diagnostics.contains { $0.issue == .duplicateDiaryID })
        #expect(duplicate.diagnostics.contains { $0.issue == .incompletePrivacyMetadata })
        #expect(!duplicate.isCompleteForCoveredTypes)
    }
}
