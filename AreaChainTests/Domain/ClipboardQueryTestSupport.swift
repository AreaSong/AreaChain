import Foundation
@testable import AreaChain

enum ClipboardQueryFixture {
    static func record(_ number: Int, _ text: String = "Alpha beta 工作") -> ClipboardHistoryRecord {
        .init(id: UUID(uuidString: String(format: "72000000-0000-0000-0000-%012d", number))!,
              copiedAt: Date(timeIntervalSince1970: 1_790_784_000), pinnedAt: nil,
              sourceBundleID: "com.example.Editor", plainText: text, html: nil, rtf: nil, imageFile: nil, contentHash: "same-hash")
    }

    static func read(_ source: String, _ records: [ClipboardHistoryRecord]) -> ClipboardQueryResponse {
        read(.unified(TodoQueryFixture.session(source)), records: .complete(records))
    }

    static func read(_ input: ClipboardQueryInput, records: ClipboardQueryRecords) -> ClipboardQueryResponse {
        ClipboardQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, input: input, records: records))
    }

    static func explicit(
        _ mode: ClipboardSearchMode, _ needle: String, _ records: [ClipboardHistoryRecord],
        filters: ContentQuerySession = TodoQueryFixture.session("/clipboard")
    ) throws -> ClipboardQueryResponse {
        read(.explicit(try .init(mode: mode, needle: needle, filters: filters)), records: .complete(records))
    }
}
