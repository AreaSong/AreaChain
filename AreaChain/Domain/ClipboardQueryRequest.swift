import Foundation

enum ClipboardQueryMode: Equatable {
    case unified
    case legacy(ClipboardSearchMode)
}

enum ClipboardQueryRequestError: Error, Equatable {
    case invalidFilters, conflictingTextConditions, unsupportedCommand
    case invalidArguments([CommandArgumentIssue])
}

/// 只有构造时通过“无文字条件”检查的 Session 才能作为独立筛选；不保存可编辑查询副本。
struct ClipboardQueryModeRequest: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let mode: ClipboardSearchMode
    let needle: String
    let filters: ContentQuerySession

    init(mode: ClipboardSearchMode, needle: String, filters: ContentQuerySession) throws {
        guard filters.isStructurallyValid else { throw ClipboardQueryRequestError.invalidFilters }
        let hasText = filters.conditions.contains { $0.value.dimension == .content(.text) }
        let hasInputText: Bool
        if case .content(let query) = filters.input {
            hasInputText = query.clauses.flatMap(\.alternatives).contains { $0.atom.dimension == .text }
        } else { hasInputText = true }
        guard !hasText, !hasInputText else { throw ClipboardQueryRequestError.conflictingTextConditions }
        self.mode = mode
        self.needle = needle
        self.filters = filters
    }

    /// 参数来自目录 chooseParameter / options；不解析或拼接自由文本尾段，不从指令推导查询范围。
    init(commandID: CommandID, arguments: [CommandArgument], filters: ContentQuerySession) throws {
        guard commandID.rawValue == "clipboard.search",
              let command = CommandCatalog.standard.command(id: commandID) else {
            throw ClipboardQueryRequestError.unsupportedCommand
        }
        let issues = CommandArgumentValidation.issues(for: arguments, command: command)
        guard issues.isEmpty else { throw ClipboardQueryRequestError.invalidArguments(issues) }
        guard case .choice(let raw) = arguments.first(where: { $0.parameter == .mode })?.value,
              let mode = ClipboardSearchMode(rawValue: raw) else {
            throw ClipboardQueryRequestError.invalidArguments([.missing(.mode)])
        }
        let needle: String
        if case .shortText(let text) = arguments.first(where: { $0.parameter == .query })?.value { needle = text }
        else { needle = "" }
        try self.init(mode: mode, needle: needle, filters: filters)
    }

    var description: String { "ClipboardQueryModeRequest(redacted)" }
    var debugDescription: String { description }
}

/// 两种入口互斥：完整统一查询，或单份模式原文加独立结构化条件。
enum ClipboardQueryInput: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case unified(ContentQuerySession)
    case explicit(ClipboardQueryModeRequest)

    var session: ContentQuerySession {
        switch self {
        case .unified(let session): session
        case .explicit(let request): request.filters
        }
    }
    var mode: ClipboardQueryMode {
        switch self {
        case .unified: .unified
        case .explicit(let request): .legacy(request.mode)
        }
    }
    var description: String { "ClipboardQueryInput(redacted)" }
    var debugDescription: String { description }
}

enum ClipboardQueryReadCoverage: Equatable { case notProvided, partial, complete, failed }

/// 覆盖和集合绑定，失败/未提供不携带可误认为当前历史的旧数组；不包含存储读取能力。
enum ClipboardQueryRecords: CustomStringConvertible, CustomDebugStringConvertible {
    case notProvided
    case partial([ClipboardHistoryRecord])
    case complete([ClipboardHistoryRecord])
    case failed

    var coverage: ClipboardQueryReadCoverage {
        switch self {
        case .notProvided: .notProvided
        case .partial: .partial
        case .complete: .complete
        case .failed: .failed
        }
    }
    var records: [ClipboardHistoryRecord] {
        switch self {
        case .partial(let records), .complete(let records): records
        case .notProvided, .failed: []
        }
    }
    var description: String { "ClipboardQueryRecords(redacted)" }
    var debugDescription: String { description }
}

struct ClipboardQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let input: ClipboardQueryInput
    let records: ClipboardQueryRecords

    var description: String { "ClipboardQueryRequest(redacted)" }
    var debugDescription: String { description }
}
