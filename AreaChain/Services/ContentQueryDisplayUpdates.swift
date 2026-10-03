import Foundation

/// 同步撤显示并传递原生焦点提示；不保存资格或展示副本，消费者仍须调用 presentation。
@MainActor
final class ContentQueryDisplayUpdates {
    enum Change { case published, invalidated, privacyInvalidated }
    private(set) var revision: UInt64 = 0
    /// 原生焦点提示仅供既有 Browse 发布算法回退；不参与读取或操作资格判断。
    var focusedControl: ContentQueryDisplayControl?
    private var observers: [UUID: (Change) -> Void] = [:]

    func observe(_ receive: @escaping (Change) -> Void) -> UUID {
        let token = UUID()
        observers[token] = receive
        return token
    }

    func remove(_ token: UUID) { observers[token] = nil }

    func send(_ change: Change) {
        if change != .published { focusedControl = nil }
        revision &+= 1
        // 允许回调卸载自己；没有把通知转成异步 SwiftUI 重绘来承担撤权。
        for receive in Array(observers.values) { receive(change) }
    }
}

extension ContentQueryReadSession {
    /// 展开仅能解析当前已展开的同批公开字段；返回值不是下次显示的缓存或读取许可。
    func expandedText(_ control: ContentQueryDisplayControl, version: UUID) throws -> String {
        let publication = try presentation()
        let browse = publication.pagination.browse
        guard browse.snapshot.version == version,
              let reference = browse.expansionReference(for: control) else {
            throw ContentQueryReadSessionError.stalePermit
        }
        guard let match = expansionIndex?.match(reference.object, in: publication),
              let text = ContentQuerySortFields(match).fields.first(where: { $0.0 == reference.field })?.1 else {
            throw ContentQueryReadSessionError.noPresentation
        }
        _ = try presentation()
        return text
    }
}
