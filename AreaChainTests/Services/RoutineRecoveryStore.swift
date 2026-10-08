import Foundation
import SwiftData
@testable import AreaChain

@available(macOS 15, *)
final class RoutineRecoveryConfiguration: DataStoreConfiguration {
    typealias Store = RoutineRecoveryStore
    let name = "routine-recovery-qa"
    var schema: Schema?
    var rejectFetch = false
    var failedFetches = 0
    static func == (lhs: RoutineRecoveryConfiguration, rhs: RoutineRecoveryConfiguration) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    func validate() throws {}
}

/// 仅保存合成初始快照的测试存储；读取故障同时覆盖仓储读取和原 rollback 的重新物化。
@available(macOS 15, *)
final class RoutineRecoveryStore: DataStore {
    typealias Configuration = RoutineRecoveryConfiguration
    typealias Snapshot = DefaultSnapshot
    let configuration: Configuration
    let identifier = UUID().uuidString
    let schema: Schema
    private var snapshots: [PersistentIdentifier: DefaultSnapshot] = [:]

    init(_ configuration: Configuration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws {
        self.configuration = configuration
        schema = configuration.schema ?? Schema(AreaChainSchema.models)
    }
    func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, DefaultSnapshot> where T: PersistentModel {
        if configuration.rejectFetch {
            configuration.failedFetches += 1
            throw CocoaError(.fileReadUnknown)
        }
        return .init(descriptor: request.descriptor,
                     fetchedSnapshots: snapshots.values.filter { $0.persistentIdentifier.entityName == String(describing: T.self) })
    }
    func save(_ request: DataStoreSaveChangesRequest<DefaultSnapshot>) throws -> DataStoreSaveChangesResult<DefaultSnapshot> {
        var remapped: [PersistentIdentifier: PersistentIdentifier] = [:]
        for snapshot in request.inserted {
            let old = snapshot.persistentIdentifier
            remapped[old] = try .identifier(for: identifier, entityName: old.entityName, primaryKey: UUID())
        }
        for snapshot in request.inserted + request.updated {
            let id = remapped[snapshot.persistentIdentifier] ?? snapshot.persistentIdentifier
            snapshots[id] = snapshot.copy(persistentIdentifier: id, remappedIdentifiers: remapped)
        }
        for snapshot in request.deleted { snapshots[snapshot.persistentIdentifier] = nil }
        return .init(for: identifier, remappedIdentifiers: remapped, snapshotsToReregister: snapshots)
    }
    func erase() throws { snapshots = [:] }
    func initializeState(for editingState: EditingState) {}
    func invalidateState(for editingState: EditingState) {}
    func cachedSnapshots(for identifiers: [PersistentIdentifier], editingState: EditingState) throws -> [PersistentIdentifier: DefaultSnapshot] {
        snapshots.filter { identifiers.contains($0.key) }
    }
}
