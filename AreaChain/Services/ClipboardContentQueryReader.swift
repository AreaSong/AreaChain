import Foundation

enum ClipboardContentQueryReadState: Equatable {
    case notRequested, missing, decodedEmpty, decodedRecords
    case failed(ClipboardHistoryReadFailure)
}

struct ClipboardContentQueryReadResult: CustomStringConvertible, CustomDebugStringConvertible {
    let batch: ContentQueryBatch
    let state: ClipboardContentQueryReadState
    var description: String { "ClipboardContentQueryReadResult(redacted)" }
    var debugDescription: String { description }
}

/// 显式存储依赖，不选择生产目录、不持有监听或运行内历史会话。
/// complete 只声明本次文件解码完整，不声明记录合法、内存历史同步或跨存储事务。
@MainActor
struct ClipboardContentQueryReader {
    private let store: ClipboardHistoryStore
    private let readData: (URL) throws -> Data

    init(store: ClipboardHistoryStore, readData: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) }) {
        self.store = store
        self.readData = readData
    }

    func read(session: ContentQuerySession, requestID: UUID,
              options: ContentQueryBatchOptions = .init()) -> ClipboardContentQueryReadResult {
        var batch = ContentQueryBatch(requestID: requestID, session: session, options: options)
        guard isRequested(session, options: options) else { return .init(batch: batch, state: .notRequested) }
        let state: ClipboardContentQueryReadState
        switch store.readHistory(readData: readData) {
        case .missing:
            batch.snapshots.clipboard = .complete([])
            state = .missing
        case .decoded(let records):
            batch.snapshots.clipboard = .complete(records)
            state = records.isEmpty ? .decodedEmpty : .decodedRecords
        case .failed(let failure):
            batch.snapshots.clipboard = .failed
            state = .failed(failure)
        }
        return .init(batch: batch, state: state)
    }

    private func isRequested(_ session: ContentQuerySession, options: ContentQueryBatchOptions) -> Bool {
        if case .command = session.input { return false }
        guard session.isStructurallyValid, session.scope == .catalog(.clipboard),
              Set(session.conditions.map(\.id)).count == session.conditions.count,
              session.typeAnalysis.types.contains(where: { $0.type == .clipboardEntry && $0.readRestriction == nil }) else {
            return false
        }
        if case .explicit(let mode, let needle) = options.clipboardMode {
            // 复用独立筛选校验；不要先读文件，再发现与统一文字条件冲突。
            return (try? ClipboardQueryModeRequest(mode: mode, needle: needle, filters: session)) != nil
        }
        return true
    }
}
