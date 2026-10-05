import Foundation
import Testing
@testable import AreaChain

final class LocalPreferenceFileFixture {
    let root: URL
    let identity = LocalPreferenceStoreIdentity(storeID: UUID(), epoch: UUID())
    static let values = LocalPreferenceValues(language: .system, appearance: .system,
                                              quadrantTitleTruncation: .tail, stampCaptureApp: false)

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Preference-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func store(_ fault: LocalPreferenceFileFault? = nil) throws -> LocalPreferenceFileStore {
        try LocalPreferenceFileStore(temporaryRoot: root, identity: identity, fault: fault)
    }

    func seed() throws -> LocalPreferenceRecord {
        guard case .committed(let record) = try store().initializeNew(values: Self.values) else {
            throw LocalPreferenceFileIssue.invalidRequest
        }
        return record
    }

    func current() throws -> LocalPreferenceRecord {
        try LocalPreferenceRecordCodec.decode(LocalPreferenceRecord.self, from: Data(contentsOf: root.appendingPathComponent("current.json")))
    }

    func write<T: Encodable>(_ value: T, name: String) throws {
        try LocalPreferenceRecordCodec.encode(value).write(to: root.appendingPathComponent(name))
    }

    func bytes(_ name: String) throws -> Data { try Data(contentsOf: root.appendingPathComponent(name)) }

    func inventory() throws -> [String: FileState] {
        var result: [String: FileState] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: root.path) {
            let path = root.appendingPathComponent(name)
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            result[name] = FileState(data: try Data(contentsOf: path),
                                     inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
                                     modified: attributes[.modificationDate] as? Date)
        }
        return result
    }

    struct FileState: Equatable {
        let data: Data
        let inode: UInt64?
        let modified: Date?
    }
}
