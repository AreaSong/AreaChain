import Foundation
import SwiftData
import Observation

/// 仅绑定注入的隔离 context。新增默认在任何保存时失效；标题按目录事实失效，避免无关字段保存造成整对象冲突。
@Observable @MainActor final class TaskCreateTagCatalogReader {
    enum Invalidation { case anySave, catalogFacts }
    private let context: ModelContext
    private let invalidation: Invalidation
    private let directoryID = UUID()
    private var readID = UUID()
    private var revision: UInt64 = 0
    private var lastDigest: [UInt8]?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(context: ModelContext, invalidation: Invalidation = .anySave) {
        self.context = context
        self.invalidation = invalidation
        guard invalidation == .anySave else { return }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.willSave,
                                                          object: context, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.revision += 1 }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func prepare() throws -> CommandTaskTagCatalog {
        readID = UUID()
        revision += 1
        return try current()
    }

    func current() throws -> CommandTaskTagCatalog {
        do {
            let rows = try SwiftDataCatalogRepository(context: context).fetchTags(includeDeleted: true)
            let records = rows.map(Self.record)
            if invalidation == .catalogFacts {
                let snapshot = CommandTaskTagCatalog(directoryID: directoryID, readID: readID, revision: revision,
                                                     coverage: .complete, records: records)
                let digest = try snapshot.evidence().digest
                if lastDigest != digest { revision += 1; lastDigest = digest }
            }
            return .init(directoryID: directoryID, readID: readID, revision: revision, coverage: .complete, records: records)
        } catch { throw TaskCreateCommandIssue.storageUnavailable }
    }

    func validate(_ evidence: CommandTaskTagCatalog.Evidence) throws -> CommandTaskTagCatalog {
        let catalog = try current()
        guard try catalog.evidence() == evidence else { throw TaskCreateCommandIssue.stale }
        return catalog
    }

    static func record(_ tag: TagItem) -> CommandTaskTagRecord {
        .init(id: tag.id, name: tag.name, state: tag.deletedAt.map { .deleted($0) } ?? .live,
              isPrivateDiary: tag.isPrivateDiary)
    }
}
