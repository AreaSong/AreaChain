import Foundation

enum ContentQueryProviderID: CaseIterable, Hashable {
    // 此顺序是临时聚合顺序，不代表相关性；提供者内部顺序原样保留。
    case todo, subtask, routine, diary, image, tag, clipboard, trash, routineOccurrence

    var types: Set<CommandObjectType> {
        switch self {
        case .todo: [.todo]
        case .subtask: [.subtask]
        case .routine: [.routine]
        case .diary: [.diary]
        case .image: [.image]
        case .tag: [.tag]
        case .clipboard: [.clipboardEntry]
        case .trash: [.todo, .subtask, .routine, .diary, .image, .tag]
        case .routineOccurrence: [.routineOccurrence]
        }
    }
}

/// 直接包裹已有安全投影，不补回输入正文，不给不同业务日期套共同 createdAt。
enum ContentQueryBatchMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    case todo(TodoQueryMatch), subtask(SubtaskQueryMatch), routine(RoutineQueryMatch)
    case diary(DiaryQueryMatch), image(ImageQueryMatch), tag(TagQueryMatch)
    case clipboard(ClipboardQueryMatch), trash(TrashQueryMatch), routineOccurrence(RoutineOccurrenceQueryMatch)

    var id: CommandObjectReference {
        switch self {
        case .todo(let value): value.id
        case .subtask(let value): value.id
        case .routine(let value): value.id
        case .diary(let value): value.id
        case .image(let value): value.id
        case .tag(let value): value.id
        case .clipboard(let value): value.id
        case .trash(let value): value.id
        case .routineOccurrence(let value): value.id
        }
    }
    var description: String { "ContentQueryBatchMatch(redacted)" }
    var debugDescription: String { description }
}

/// 同一来源一份反馈；原诊断、条件身份、覆盖、公开 owner、组与剩余工作均保留。
/// 没有接受外部响应的批次入口，不能用相同 requestID 拼接别的查询。
enum ContentQueryProviderRead: CustomStringConvertible, CustomDebugStringConvertible {
    case todo(TodoQueryResponse), subtask(SubtaskQueryResponse), routine(RoutineQueryResponse)
    case diary(DiaryQueryResponse), image(ImageQueryResponse), tag(TagQueryResponse)
    case clipboard(ClipboardQueryResponse), trash(TrashQueryResponse), routineOccurrence(RoutineOccurrenceQueryResponse)

    var provider: ContentQueryProviderID {
        switch self {
        case .todo: .todo
        case .subtask: .subtask
        case .routine: .routine
        case .diary: .diary
        case .image: .image
        case .tag: .tag
        case .clipboard: .clipboard
        case .trash: .trash
        case .routineOccurrence: .routineOccurrence
        }
    }
    var matches: [ContentQueryBatchMatch] {
        switch self {
        case .todo(let value): value.matches.map(ContentQueryBatchMatch.todo)
        case .subtask(let value): value.matches.map(ContentQueryBatchMatch.subtask)
        case .routine(let value): value.matches.map(ContentQueryBatchMatch.routine)
        case .diary(let value): value.matches.map(ContentQueryBatchMatch.diary)
        case .image(let value): value.matches.map(ContentQueryBatchMatch.image)
        case .tag(let value): value.matches.map(ContentQueryBatchMatch.tag)
        case .clipboard(let value): value.matches.map(ContentQueryBatchMatch.clipboard)
        case .trash(let value): value.matches.map(ContentQueryBatchMatch.trash)
        case .routineOccurrence(let value): value.matches.map(ContentQueryBatchMatch.routineOccurrence)
        }
    }
    var state: TodoQueryReadState {
        switch self {
        case .todo(let value): value.state
        case .subtask(let value): value.state
        case .routine(let value): value.state
        case .diary(let value): value.state
        case .image(let value): value.state
        case .tag(let value): value.state
        case .clipboard(let value): value.state
        case .trash(let value): value.state == .evaluated ? .evaluated : (value.state == .invalidQuery ? .invalidQuery : .notApplicable)
        case .routineOccurrence(let value): value.state
        }
    }
    var description: String { "ContentQueryProviderRead(redacted)" }
    var debugDescription: String { description }
}

enum ContentQueryBatchQueryState: Equatable { case content, invalidStructure, commandInput }
enum ContentQueryBatchOrder: Equatable { case temporaryProviderThenInput }

enum ContentQueryBatchConsistencyIssue: Equatable {
    case nestedSubtaskInput
    case uncontainedSubtasks
    case conflictingIdentity(provider: ContentQueryProviderID, object: CommandObjectReference)
}

struct ContentQueryBatchResponse: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let sortContext: ContentQuerySortContext
    let queryState: ContentQueryBatchQueryState
    let typeAnalysis: ContentQueryTypeAnalysis
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    let readings: [ContentQueryProviderRead]
    let completeness: ContentQueryBatchCompleteness
    let consistencyIssues: [ContentQueryBatchConsistencyIssue]
    var order: ContentQueryBatchOrder { .temporaryProviderThenInput }
    var matches: [ContentQueryBatchMatch] { readings.flatMap(\.matches) }
    var definiteMatchCount: Int { readings.reduce(0) { $0 + $1.matches.count } }
    var visibleGroupCount: Int { readings.reduce(0) { count, read in
        if case .trash(let value) = read { return count + value.visibleGroupCount }; return count
    } }
    var visibleContextCount: Int { readings.reduce(0) { count, read in
        if case .trash(let value) = read { return count + value.visibleContextCount }; return count
    } }
    var canDeclareCompleteNoMatch: Bool { completeness.matchingIsComplete && definiteMatchCount == 0 }
    var description: String { "ContentQueryBatchResponse(redacted)" }
    var debugDescription: String { description }
}
