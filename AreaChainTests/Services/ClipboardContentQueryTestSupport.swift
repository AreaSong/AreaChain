import Foundation
import Testing
@testable import AreaChain

/// 沿旧存储测试使用显式临时 root；夹具直接写合成格式，不经过采集、save 或图片接口。
@MainActor
final class ClipboardFileFixture {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "areachain-clipboard-read-\(UUID().uuidString)", directoryHint: .isDirectory)
    var file: URL { root.appending(path: "history.json") }
    var store: ClipboardHistoryStore { .init(root: root) }
    var reader: ClipboardContentQueryReader { .init(store: store) }

    func write(_ records: [ClipboardHistoryRecord]) throws {
        try writeData(JSONEncoder().encode(["items": records]))
    }

    func writeData(_ data: Data) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: file)
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }

    func read(_ input: String = "/clipboard", options: ContentQueryBatchOptions = .init()) -> ClipboardContentQueryReadResult {
        reader.read(session: TodoQueryFixture.session(input), requestID: TodoQueryFixture.requestID, options: options)
    }

    static func response(_ result: ClipboardContentQueryReadResult) throws -> ClipboardQueryResponse {
        let response = ContentQueryBatchReader.read(result.batch)
        return try #require(response.readings.compactMap { read in
            if case .clipboard(let value) = read { return value }
            return nil
        }.first)
    }
}

@MainActor
final class ClipboardSearchFixture {
    let files = ClipboardFileFixture()
    let handoff: HandoffFixture
    let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
    let model = NotificationCenter()
    let focus = NotificationCenter()
    let focusObject = NSObject()
    let session: ContentQueryReadSession

    init() throws {
        handoff = try .init(sourcePage: .overview)
        try handoff.send(.query(.setInput("/clipboard")))
        session = try .init(vault: vault, coordinator: handoff.coordinator,
            ownership: handoff.owned().lease.ownership,
            notifications: .init(privacy: .default, model: model, focus: focus,
                focusLost: SearchReadFixture.focusLost, focusObject: focusObject))
        session.install()
    }

    func cleanup() { session.detach(); files.cleanup() }
    var lease: CommandHostLease { get throws { try handoff.owned().lease } }

    @discardableResult
    func prepare(reader: ClipboardContentQueryReader? = nil, options: ContentQueryBatchOptions = .init()) throws
        -> ContentQueryReadHandle {
        try session.prepareClipboard(reader: reader ?? files.reader,
            requestID: TodoQueryFixture.requestID, options: options).handle
    }

    @discardableResult
    func publish(_ handle: ContentQueryReadHandle? = nil) async throws -> ContentQueryReadPublication {
        let current = try handle ?? prepare()
        try session.evaluate(current)
        #expect(try await session.publish(current).outcome == .published)
        return try session.presentation()
    }

    func settle() async {
        for _ in 0..<200 where !session.isTrackingReady { await Task.yield() }
        #expect(session.isTrackingReady)
    }
}
