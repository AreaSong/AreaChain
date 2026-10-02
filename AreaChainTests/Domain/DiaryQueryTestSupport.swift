import Foundation
@testable import AreaChain

enum DiaryQueryFixture {
    static let names = [TodoQueryFixture.work: "合成工作", TodoQueryFixture.study: "学习笔记"]
    static let metadata = DiaryQueryMetadata(tagNames: names, privateTagIDs: [])
    static let locale = Locale(identifier: "zh-Hans")
    static var secret: String { ["DIARY", "SYNTHETIC", "ONLY", "MARKER"].joined(separator: "_") }

    static func diary(_ number: Int = 1, text: String = "公开合成正文") -> DiarySnapshot {
        .init(id: UUID(uuidString: String(format: "60000000-0000-0000-0000-%012d", number))!,
              text: text, dayKey: QuerySessionFixture.today, createdAt: TodoQueryFixture.created)
    }

    static func unreadable(_ number: Int = 1) -> DiarySnapshot {
        var value = diary(number, text: "不可搜索的占位文本")
        value.isContentAvailable = false
        value.isPrivate = true
        value.tagIDs = TodoQueryFixture.work.uuidString
        return value
    }

    static func request(_ session: ContentQuerySession, _ diaries: [DiarySnapshot],
                        metadata: DiaryQueryMetadata = metadata, locale: Locale = locale) -> DiaryQueryRequest {
        .init(requestID: TodoQueryFixture.requestID, session: session, diaries: diaries, metadata: metadata, locale: locale)
    }

    static func read(_ source: String, _ diaries: [DiarySnapshot], metadata: DiaryQueryMetadata = metadata) -> DiaryQueryResponse {
        read(TodoQueryFixture.session(source), diaries, metadata: metadata)
    }

    static func read(_ session: ContentQuerySession, _ diaries: [DiarySnapshot],
                     metadata: DiaryQueryMetadata = metadata) -> DiaryQueryResponse {
        DiaryQueryProvider.read(request(session, diaries, metadata: metadata))
    }

    /// 递归检查实际存储值，不只相信 description 的遮罩。
    static func containsSecret(_ value: Any) -> Bool {
        if let text = value as? String { return text.contains(secret) }
        return Mirror(reflecting: value).children.contains { containsSecret($0.value) }
    }
}
