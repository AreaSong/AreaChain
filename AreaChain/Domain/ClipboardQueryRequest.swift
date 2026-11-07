import Foundation

enum ClipboardQueryMode: Equatable {
    case unified
    case legacy(ClipboardSearchMode)
}

enum ClipboardQueryRequestError: Error, Equatable {
    case invalidFilters, conflictingTextConditions, unsupportedCommand
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
