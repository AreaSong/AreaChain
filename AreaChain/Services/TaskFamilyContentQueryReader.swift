import Foundation
import SwiftData

struct TaskFamilyContentQueryReadResult: CustomStringConvertible, CustomDebugStringConvertible {
    let batch: ContentQueryBatch
    let taskIssues: [TaskContentQueryReadIssue]
    let routine: RoutineContentQueryReadDetails
    let diary: DiaryContentQueryReadDetails
    let diaryTagPrivacy: DiaryContentQueryTagPrivacy?
    let tagCatalog: TagContentQueryReadDetails
    let tagIssues: [ContentQueryTagNameIssue]
    let tagNamesCoverage: ContentQuerySourceCoverage
    var description: String { "TaskFamilyContentQueryReadResult(redacted)" }
    var debugDescription: String { description }
}

/// 一个上下文、一次同步装配、一份 metadata；不合并两个独立 Batch 的覆盖声明。
/// 注入闭包仅供只读故障验证，调用方须保证同一上下文且不插入修改；不提供任意回调钩子。
@MainActor
struct TaskFamilyContentQueryReader {
    private let tasks: TaskContentQueryReads
    private let routines: RoutineContentQueryReads
    private let diaries: DiaryContentQueryReads?
    private let tags: TagContentQueryReads

    init(context: ModelContext, diaryMode: DiaryContentQueryReadMode? = nil) {
        diaries = diaryMode == .metadataOnly ? .init(context: context) : nil
        tasks = .init(context: context)
        routines = .init(context: context)
        tags = .init(context: context)
    }

    init(tasks: TaskContentQueryReads, routines: RoutineContentQueryReads, tags: TagContentQueryReads,
         diaries: DiaryContentQueryReads? = nil) {
        self.diaries = diaries
        self.tasks = tasks
        self.routines = routines
        self.tags = tags
    }

    func read(session: ContentQuerySession, requestID: UUID, observation: RoutineContentQueryObservation,
              options: ContentQueryBatchOptions = .init(),
              injectedUsage: TagQueryUsageInput? = nil,
              imageOwners: Set<AttachmentOwner> = [],
              storedUsage: TagUsageContentQueryStatistics? = nil) -> TaskFamilyContentQueryReadResult {
        var batch = ContentQueryBatch(requestID: requestID, session: session, options: options)
        var taskIssues: [TaskContentQueryReadIssue] = []
        let didReadTasks = TaskContentQueryReader(reads: tasks).readSources(into: &batch, issues: &taskIssues,
                                                                          imageOwner: imageOwners.contains(.todo))
        let routine = RoutineContentQueryReader(reads: routines).readSources(into: &batch, observation: observation,
                                                                            imageOwner: imageOwners.contains(.routine))
        let diary = diaries.map { DiaryContentQueryReader(reads: $0).readSources(into: &batch,
                                                imageOwner: imageOwners.contains(.diary)) } ?? .init()
        let needsDiaryMetadata = diary.source == .complete
        let catalog = TagContentQueryReader(reads: tags).readSources(into: &batch, injectedUsage: injectedUsage,
            requiresDiaryMetadata: needsDiaryMetadata, storedUsage: storedUsage)
        let names: ContentQueryTagNames
        if didReadTasks || batch.snapshots.routines.coverage != .notProvided || needsDiaryMetadata {
            names = catalog.associatedNames ?? .read(ContentQueryTagNames.associatedIDs(in: batch), fetch: tasks.tags)
        } else { names = .init(values: nil, coverage: .notProvided, issues: []) }
        batch.facts.metadata = .init(tagNames: names.values, privateTagIDs: catalog.diaryPrivacy?.privateTagIDs)
        return .init(batch: batch, taskIssues: taskIssues, routine: routine,
                     diary: diary, diaryTagPrivacy: catalog.diaryPrivacy, tagCatalog: catalog.details,
                     tagIssues: names.issues, tagNamesCoverage: names.coverage)
    }
}
