import Foundation

enum ContentQuerySourceCoverage: Equatable { case notProvided, failed, partial, complete }

/// complete 声明包含墓碑及重复身份核验所需行；只是注入值的声明，不是数据库事务证明。
enum ContentQueryBatchSource<Value>: CustomStringConvertible, CustomDebugStringConvertible {
    case notProvided, failed
    case partial([Value]), complete([Value])

    var values: [Value]? {
        switch self {
        case .notProvided, .failed: nil
        case .partial(let values), .complete(let values): values
        }
    }
    var coverage: ContentQuerySourceCoverage {
        switch self {
        case .notProvided: .notProvided
        case .failed: .failed
        case .partial: .partial
        case .complete: .complete
        }
    }
    var description: String { "ContentQueryBatchSource(redacted)" }
    var debugDescription: String { description }
}

/// 子任务只有平面数组这一份权威来源，父任务输入不得再内嵌子项。
/// 活提供者所需的嵌套视图在同次读取中只装配一次；墓碑保留孤立子项的原始归属。
struct ContentQueryBatchSnapshots: CustomStringConvertible, CustomDebugStringConvertible {
    var todos: ContentQueryBatchSource<TodoSnapshot> = .notProvided
    var subtasks: ContentQueryBatchSource<SubtaskSnapshot> = .notProvided
    var routines: ContentQueryBatchSource<RoutineSnapshot> = .notProvided
    var diaries: ContentQueryBatchSource<DiarySnapshot> = .notProvided
    var images: ContentQueryBatchSource<ImageAttachmentMetadata> = .notProvided
    var tags: ContentQueryBatchSource<TagQuerySnapshot> = .notProvided
    var clipboard: ClipboardQueryRecords = .notProvided

    var description: String { "ContentQueryBatchSnapshots(redacted)" }
    var debugDescription: String { description }
}

enum RoutineCheckSourceProblem: Equatable { case incompleteUnattributedInput, readFailed }

struct ContentQueryBatchRoutineFacts: CustomStringConvertible, CustomDebugStringConvertible {
    var checks: [CheckSnapshot] = []
    var checkCoverage: [RoutineCheckCoverage] = []
    var scheduleEvidence: [RoutineScheduleEvidence] = []
    /// 无法归属到习惯的丢失输入或 fetch 失败必须跨过空定义集；nil 不声明记录完整。
    var checkSourceProblem: RoutineCheckSourceProblem?
    var description: String { "ContentQueryBatchRoutineFacts(redacted)" }
    var debugDescription: String { description }
}

/// 不接收另一个 Session、owner 数组或预计算响应。所有名字与保护判断共用同一 metadata。
struct ContentQueryBatchFacts: CustomStringConvertible, CustomDebugStringConvertible {
    var metadata = DiaryQueryMetadata(tagNames: nil, privateTagIDs: nil)
    var imageCoverage = ImageAssociationCoverage()
    var imagePrivacy: DiaryImageProtectionFacts?
    var routine = ContentQueryBatchRoutineFacts()
    var tagUsage: TagQueryUsageInput?
    var trashCoverage = TrashReadCoverage()
    var trashUnconvertedSubtaskIDs: [UUID] = []
    var trashTagNamesCoverage: TrashReadCompleteness = .notProvided
    var description: String { "ContentQueryBatchFacts(redacted)" }
    var debugDescription: String { description }
}

enum ContentQueryBatchClipboardMode: CustomStringConvertible, CustomDebugStringConvertible {
    case unified
    case explicit(ClipboardSearchMode, needle: String)
    var description: String { "ContentQueryBatchClipboardMode(redacted)" }
    var debugDescription: String { description }
}

struct ContentQueryBatchOptions: CustomStringConvertible, CustomDebugStringConvertible {
    var locale = Locale(identifier: "en")
    var tagView: TagQueryView = .inputOrder
    var clipboardMode: ContentQueryBatchClipboardMode = .unified
    var occurrenceWindow: ContentQueryDateWindow?
    var occurrenceBudget = RoutineOccurrenceQueryBudget()
    var description: String { "ContentQueryBatchOptions(redacted)" }
    var debugDescription: String { description }
}

/// 同步调用只保证这份值输入的一致性。日期唯一取自 Session（含转交冻结日期），不另设第二份日期选项。
/// requestID 仅关联证据/输入下标；没有快照版本、授权、异步新鲜度或跨线程承诺。
struct ContentQueryBatch: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    var snapshots = ContentQueryBatchSnapshots()
    var facts = ContentQueryBatchFacts()
    var options = ContentQueryBatchOptions()
    var dates: ContentQueryDateContext { session.queryDates }
    var description: String { "ContentQueryBatch(redacted)" }
    var debugDescription: String { description }
}
