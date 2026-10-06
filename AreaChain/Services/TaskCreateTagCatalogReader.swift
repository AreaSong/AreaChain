import Foundation
import SwiftData

/// 仅绑定注入的隔离 context。新预览换读取身份，复核重枚举同一读取；任何保存尝试保守推进版本。
@MainActor final class TaskCreateTagCatalogReader {
    private let context: ModelContext
    private let directoryID = UUID()
    private var readID = UUID()
    private var revision: UInt64 = 0
    private var observer: NSObjectProtocol?

    init(context: ModelContext) {
        self.context = context
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
            return .init(directoryID: directoryID, readID: readID, revision: revision,
                         coverage: .complete, records: rows.map(Self.record))
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
