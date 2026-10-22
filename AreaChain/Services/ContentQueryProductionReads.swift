import Foundation
import SwiftData

/// 合并批 M-6：正式版统一搜索的唯一读取装配。四种受门禁读取（普通＋图片、回收站、标签统计、剪贴板历史）
/// 共用同一 context 与只读依赖，由 `ContentQueryReadSession(vault:reads:…)` 的同一 owner 发布；
/// 手记正文只读普通手记（ordinaryOnly），受保护手记即使已解锁也不解密。只读，不 save、不发事件。
@MainActor struct ContentQueryProductionReads {
    let images: ImageContentQueryReads
    let trash: TrashContentQueryReads
    let tagUsage: TagUsageContentQueryReads
    let clipboard: ClipboardContentQueryReader
    let calendar: Calendar
    let now: () -> Date
    /// 输入到读取之间的合并等待：连续输入只读最后一次，期间让出主线程处理按键。
    var settle: Duration = .milliseconds(120)

    init(context: ModelContext, clipboard: ClipboardHistoryStore, calendar: Calendar = .current,
         now: @escaping () -> Date = { Date() }) {
        let bodies = ContentQueryBodyReads(context: context, ordinaryOnly: true)
        images = .init(context: context, bodies: bodies)
        trash = .init(context: context, bodies: bodies)
        tagUsage = .init(context: context)
        self.clipboard = .init(store: clipboard)
        self.calendar = calendar
        self.now = now
    }

    var observation: RoutineContentQueryObservation { .init(instant: now(), calendar: calendar) }

    enum Route: Equatable { case clipboard, trash, tagUsage, content }

    /// 只按协调者当前查询选路；四条路都在会话内部建许可，宿主拿不到 Batch。
    static func route(_ query: ContentQuerySession) -> Route {
        if query.scope == .catalog(.clipboard) { return .clipboard }
        if !TrashContentQueryPlan.types(query).isEmpty { return .trash }
        if TagUsageContentQueryPlan.needsUsage(query, options: .init()) { return .tagUsage }
        return .content
    }

    /// 合作式取消：等待、准备、求值、发布之间逐段检查；被新输入取消时抛 CancellationError，不发布旧结果。
    func read(_ session: ContentQueryReadSession, query: () throws -> ContentQuerySession) async throws -> ContentQueryReadEffect {
        try await Task.sleep(for: settle)
        try Task.checkCancellation()
        let handle: ContentQueryReadHandle
        switch Self.route(try query()) {
        case .clipboard: handle = try session.prepareClipboard(reader: clipboard, requestID: UUID()).handle
        case .trash: handle = try session.prepareTrash(observation: observation).handle
        case .tagUsage: handle = try session.prepareTagUsage(observation: observation).handle
        case .content: handle = try session.prepareImages(observation: observation)
        }
        do {
            try Task.checkCancellation()
            try session.evaluate(handle)
            try Task.checkCancellation()
        } catch {
            try? session.cancel(handle)
            throw error
        }
        return try await session.publish(handle)
    }
}
