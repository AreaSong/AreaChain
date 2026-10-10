import Foundation
import Observation

/// 一次查阅独占其全文/图像；搜索、返回票据、Draft、Plan 和 Run 都不持有这些值。
@Observable @MainActor final class WorkspaceContentSession {
    let reader: WorkspaceContentReader
    private(set) var content: WorkspaceReadOnlyContent?
    private(set) var target: CommandObjectReference?
    private(set) var failure: WorkspaceContentFailure?
    private(set) var loading = false
    @ObservationIgnored private var source: WorkspaceContentSource?
    @ObservationIgnored private var sourceTask: ContentQueryReadTask?
    @ObservationIgnored private var permit: ContentQueryBodyReadPermit?
    @ObservationIgnored private var request: UUID?
    @ObservationIgnored private var gate: ContentQueryReadGate?
    @ObservationIgnored private var validateCurrent: (() throws -> Void)?
    @ObservationIgnored private var invalidateSearchSource: (() -> Void)?
    @ObservationIgnored private var file: WorkspaceContentFile?

    init(reader: WorkspaceContentReader) { self.reader = reader }

    func captureSource() throws -> WorkspaceContentSource { try reader.source() }

    func bindSource(_ source: WorkspaceContentSource, publication: ContentQueryReadPublication) throws {
        guard try reader.source() == source else { throw WorkspaceContentFailure.stale }
        self.source = source
        sourceTask = publication.task
    }

    func open(_ open: ContentQueryBrowseOpen, session: ContentQueryReadSession,
              lease: CommandHostLease, version: UUID, origin: CommandObjectReference? = nil) async {
        let ownerAllowed = origin == target && origin != nil && allowsOwner(open.object)
        clear()
        target = open.object
        loading = true
        let id = UUID()
        request = id
        let gate = ContentQueryReadGate()
        self.gate = gate
        do {
            let publication = try session.presentation()
            guard publication.task == sourceTask, let source,
                  publication.pagination.snapshot.visible.contains(open.object) || ownerAllowed else { throw WorkspaceContentFailure.stale }
            let permit = try session.contentPermit(expecting: lease, version: version)
            self.permit = permit
            invalidateSearchSource = { [weak session] in try? session?.modelDidChange(expecting: lease.ownership) }
            let check = { [weak self] in
                guard let self, self.request == id, gate.state.epoch == 0, !Task.isCancelled,
                      try self.reader.source() == source else { throw WorkspaceContentFailure.stale }
            }
            permit.retainFacts(check)
            validateCurrent = { try permit.validate() }
            var activeReader = reader
            var sourceError: Error?
            let current = withObservationTracking { () -> WorkspaceContentSource? in
                do {
                    return try activeReader.source()
                } catch {
                    sourceError = error
                    return nil
                }
            } onChange: { [weak self] in
                gate.deliver(.observation) { [weak self] _ in self?.invalidate(id: id) }
            }
            if let sourceError { throw sourceError }
            guard let current, current == source else { throw WorkspaceContentFailure.stale }
            activeReader.contentChanged = { [weak self] in self?.invalidate(id: id) }
            activeReader.watchFile = { [weak self] url in
                guard let self, self.request == id else { throw WorkspaceContentFailure.stale }
                let file = try WorkspaceContentFile(url: url) { [weak self] in self?.invalidate(id: id) }
                self.file = file
                permit.retainFacts { try file.validate() }
            }
            let value = try await activeReader.read(open, permit: permit)
            await Task.yield()
            try permit.validate()
            guard request == id else { return }
            content = value
            loading = false
        } catch {
            guard request == id else { return }
            invalidate(id: id, failure: error as? WorkspaceContentFailure ?? .invalidTarget)
        }
    }

    func validate() -> Bool {
        do { guard let validateCurrent, content != nil else { return false }; try validateCurrent(); return true }
        catch { invalidate(); return false }
    }

    func allowsOwner(_ owner: CommandObjectReference) -> Bool {
        guard validate(), case .image(_, _, let actual, _) = content else { return false }
        return owner == actual
    }

    func invalidate(id: UUID? = nil, failure: WorkspaceContentFailure = .stale) {
        if let id, request != id { return }
        let revoke = invalidateSearchSource
        clear()
        source = nil; sourceTask = nil
        self.failure = failure
        if failure == .stale { revoke?() }
    }

    func clear() {
        gate?.detach(); gate = nil
        request = nil; permit = nil; validateCurrent = nil
        invalidateSearchSource = nil
        file = nil
        content = nil; target = nil; loading = false; failure = nil
    }
}
