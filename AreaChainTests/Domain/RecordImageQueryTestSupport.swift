import Foundation
@testable import AreaChain

enum RecordImageQueryFixture {
    static let id = ImageAssociationFixture.key.id
    static let otherID = TodoQueryFixture.work
    static let metadata = DiaryQueryMetadata(tagNames: [:], privateTagIDs: [])

    static func input(_ images: [ImageAttachmentMetadata]? = [],
                      coverage: ImageAssociationCoverage = ImageAssociationFixture.coverage) -> ContentQueryImageInput {
        .init(images: images, coverage: coverage)
    }

    static func image(_ kind: AttachmentOwner, id: UUID = id) -> ImageAttachmentMetadata {
        ImageAssociationFixture.image(owner: .init(kind: kind, id: id))
    }

    static func todo(_ source: String = "has:image", values: [TodoSnapshot] = [ImageAssociationFixture.todo()],
                     input: ContentQueryImageInput? = nil) -> TodoQueryResponse {
        TodoQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: TodoQueryFixture.session(source),
                                     todos: values, tagNames: TodoQueryFixture.names, subtaskData: .includedInSnapshots,
                                     imageInput: input))
    }

    static func routine(_ source: String = "/routines has:image",
                        values: [RoutineSnapshot] = [ImageAssociationFixture.routine()],
                        input: ContentQueryImageInput? = nil) -> RoutineQueryResponse {
        RoutineQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: TodoQueryFixture.session(source),
                                        routines: values, tagNames: TodoQueryFixture.names,
                                        checks: [], checkCoverage: [], scheduleEvidence: [], imageInput: input))
    }

    static func diary(_ source: String = "/diaries has:image",
                      values: [DiarySnapshot] = [ImageAssociationFixture.diary()],
                      input: ContentQueryImageInput? = nil, metadata: DiaryQueryMetadata = metadata) -> DiaryQueryResponse {
        DiaryQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: TodoQueryFixture.session(source),
                                      diaries: values, metadata: metadata, locale: DiaryQueryFixture.locale, imageInput: input))
    }

    /// 只将三个真实响应的可观察字段并列，便于在相同合成输入上检查共同契约。
    struct Observation {
        let matches: [CommandObjectReference]
        let unknown: [CommandObjectReference]
        let complete: Bool
        let issues: [ContentQueryImageIssue]
        let affects: [Bool]
        let evidence: [ContentQueryMatchEvidence]
    }

    static func observe(_ kind: AttachmentOwner, input: ContentQueryImageInput?) -> Observation {
        switch kind {
        case .todo:
            let result = todo(input: input)
            return .init(matches: result.matches.map(\.id), unknown: result.undeterminedObjects,
                         complete: result.isCompleteForCoveredTypes, issues: result.diagnostics.compactMap {
                            if case .imageAssociation(let issue) = $0.issue { return issue }; return nil
                         }, affects: result.diagnostics.map(\.affectsDetermination), evidence: result.matches.flatMap(\.evidence))
        case .routine:
            let result = routine(input: input)
            return .init(matches: result.matches.map(\.id), unknown: result.undeterminedObjects,
                         complete: result.isCompleteForCoveredTypes, issues: result.diagnostics.compactMap {
                            if case .imageAssociation(let issue) = $0.issue { return issue }; return nil
                         }, affects: result.diagnostics.map(\.affectsDetermination), evidence: result.matches.flatMap(\.evidence))
        case .diary:
            let result = diary(input: input)
            return .init(matches: result.matches.map(\.id), unknown: result.undeterminedObjects,
                         complete: result.isCompleteForCoveredTypes, issues: result.diagnostics.compactMap {
                            if case .imageAssociation(let issue) = $0.issue { return issue }; return nil
                         }, affects: result.diagnostics.map(\.affectsDetermination), evidence: result.matches.flatMap(\.metadataEvidence))
        }
    }
}
